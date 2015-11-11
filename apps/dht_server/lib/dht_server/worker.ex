defmodule DHTServer.Worker do
  use GenServer

  require Logger

  alias DHTServer.Utils,     as: Utils
  alias DHTServer.Storage,   as: Storage

  alias RoutingTable.Node,   as: Node
  alias RoutingTable.Search, as: Search
  alias RoutingTable.Worker, as: RoutingTable

  @name __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def bootstrap do
    GenServer.cast(@name, :bootstrap)
  end

  def search do
    GenServer.cast(@name, :search)
  end

  def init([]), do: init([port: 0])

  def init(port: port) do
    case :gen_udp.open port, [{:active, true}] do
      {:ok, socket} ->
        node_id = Utils.gen_node_id
        {:ok, port} = :inet.port(socket)

        Logger.debug "Init DHT Node"
        Logger.debug "Node-ID: #{Hexate.encode node_id}"
        Logger.debug "UDP Port:#{port}"

        ## Change secret of the token every 5 minutes
        Process.send_after(self(), :change_secret, 60 * 1000 * 5)

        ## Setup RoutingTable
        RoutingTable.node_id(node_id)

        {:ok, %{node_id: node_id, socket: socket, old_secret: nil,
                secret: Utils.gen_secret}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_cast(:bootstrap, state) do
    cfg = Application.get_all_env(:dht_server)

    nodes = Enum.map(cfg[:bootstrap_nodes], fn(node) ->
      {id, host, port} = node
      case :inet.getaddr(String.to_char_list(host), :inet) do
        {:ok, ip_addr}  -> {id, ip_addr, port}
        {:error, _code} -> Logger.error "Couldn't resolve the hostname #{host}"
      end
    end)

    Search.start_link(:find_node, state.node_id, state.node_id, nodes, state.socket)

    {:noreply, state}
  end

  def handle_cast(:search, state) do
    ## Ubuntu 15.10 (64 bit)
    infohash = "3f19b149f53a50e14fc0b79926a391896eabab6f" |> Hexate.decode
    nodes = RoutingTable.closest_nodes(infohash)

    Search.start_link(:get_peers, state.node_id, infohash, nodes, state.socket, 6881)

    {:noreply, state}
  end


  def handle_info(:change_secret, state) do
    Logger.debug "Change Secret"
    {:noreply, %{state | old_secret: state.secret, secret: Utils.gen_secret()}}
  end


  def handle_info({:udp, socket, ip, port, raw_data}, state) do
    # Logger.debug "[#{Utils.tuple_to_ipstr(ip, port)}]\n"
    # <> PrettyHex.pretty_hex(to_string(raw_data))

    raw_data
    |> :binary.list_to_bin
    |> String.rstrip(?\n)
    |> KRPCProtocol.decode
    |> handle_message(socket, ip, port, state)
  end

  #########
  # Error #
  #########

  def handle_message({:error, error}, _socket, ip, port, state) do
    args    = [code: error.code, msg: error.msg, tid: error.tid]
    payload = KRPCProtocol.encode(:error, args)
    :gen_udp.send(state.socket, ip, port, payload)

    {:noreply, state}
  end

  def handle_message({:ignore, msg}, _socket, _ip, _port, state) do
    Logger.error "Ignore unknown or corrupted message: #{inspect msg, limit: 5000}"
    ## Maybe we should blacklist this filthy peer?

    {:noreply, state}
  end


  ########################
  # Incoming DHT Queries #
  ########################

  def handle_message({:ping, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> ping"
    query_received(remote.node_id, {ip, port}, socket)

    send_ping_reply(remote.node_id, remote.tid, ip, port, socket)

    {:noreply, state}
  end

  def handle_message({:find_node, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> find_node"
    query_received(remote.node_id, {ip, port}, socket)

    ## Get closest nodes for the requested target
    nodes = Enum.map(RoutingTable.closest_nodes(remote.target), fn(pid) ->
      Node.to_tuple(pid)
    end)

    Logger.debug("[#{Hexate.encode(remote.node_id)}] << find_node_reply")
    args = [node_id: state.node_id, nodes: nodes, tid: remote.tid]
    payload = KRPCProtocol.encode(:find_node_reply, args)
    :gen_udp.send(state.socket, ip, port, payload)

    {:noreply, state}
  end

  ## Get_peers

  def handle_message({:get_peers, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> get_peers"
    query_received(remote.node_id, {ip, port}, socket)

    ## Generate a token for the requesting node
    token = :crypto.hash(:sha, Utils.tuple_to_ipstr(ip, port) <> state.secret)

    if Storage.has_nodes_for_infohash?(remote.info_hash) do
      values = Storage.get_nodes(remote.info_hash)

      Logger.debug "Sending values: #{inspect values}"
      Logger.debug("[#{Hexate.encode(remote.node_id)}] << get_peers_reply (values)")
      args = [node_id: state.node_id, values: values, tid: remote.tid, token: token]
    else
      ## Get the closest nodes for the requested info_hash
      nodes = Enum.map(RoutingTable.closest_nodes(remote.info_hash), fn(pid) ->
        Node.to_tuple(pid)
      end)

      Logger.debug("[#{Hexate.encode(remote.node_id)}] << get_peers_reply (nodes)")
      args = [node_id: state.node_id, nodes: nodes, tid: remote.tid, token: token]
    end

    payload = KRPCProtocol.encode(:get_peers_reply, args)
    :gen_udp.send(state.socket, ip, port, payload)

    {:noreply, state}
  end

  ## Announce_peer

  def handle_message({:announce_peer, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> announce_peer"
    query_received(remote.node_id, {ip, port}, socket)

    if token_match(remote.token, ip, port, state.secret, state.old_secret) do
      Logger.debug "Valid Token"
      Logger.debug "#{inspect remote}"

      Storage.put(remote.info_hash, ip, port)

      ## Sending a ping_reply back as an acknowledgement
      send_ping_reply(remote.node_id, remote.tid, ip, port, socket)

      {:noreply, state}
    else
      Logger.debug("[#{Hexate.encode(remote.node_id)}] << error (invalid token})")

      args = [code: 203, msg: "Announce_peer with wrong token", tid: remote.tid]
      payload = KRPCProtocol.encode(:error, args)
      :gen_udp.send(state.socket, ip, port, payload)

      {:noreply, state}
    end
  end


  ########################
  # Incoming DHT Replies #
  ########################

  def handle_message({:error_reply, error}, _socket, _ip, _port, state) do
    Logger.error "[#{__MODULE__}] >> error (#{error.code}: #{error.msg})"

    {:noreply, state}
  end

  def handle_message({:find_node_reply, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> find_node_reply"
    response_received(remote.node_id, {ip, port}, socket)

    pname = Search.tid_to_process_name(remote.tid)
    if Search.is_active?(remote.tid) do
      ## If this belongs to an active search, it is actuall a get_peers_reply
      ## without a token.
      if Search.type(pname) == :get_peers do
        handle_message({:get_peer_reply, remote}, socket, ip, port, state)
      else
        Search.handle_reply(pname, remote, remote.nodes)
      end
    end

    ## Ping all nodes
    payload = KRPCProtocol.encode(:ping, node_id: state.node_id)
    Enum.map(remote.nodes, fn(node) ->
      {_id, {ip, port}} = node
      :gen_udp.send(state.socket, ip, port, payload)
    end)

    {:noreply, state}
  end

  def handle_message({:get_peer_reply, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> get_peer_reply"
    response_received(remote.node_id, {ip, port}, socket)

    if remote.values do
      Logger.info "Found value: #{inspect remote.values}"
    end

    pname = Search.tid_to_process_name(remote.tid)
    if Search.is_active?(remote.tid) do
      Search.handle_reply(pname, remote, remote.nodes)
    end

    {:noreply, state}
  end

  def handle_message({:ping_reply, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> ping_reply"
    response_received(remote.node_id, {ip, port}, socket)

    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################

  def send_ping_reply(node_id, tid, ip, port, socket) do
    Logger.debug("[#{Hexate.encode(node_id)}] << ping_reply")

    payload = KRPCProtocol.encode(:ping_reply, tid: tid, node_id: node_id)
    :gen_udp.send(socket, ip, port, payload)
  end


  defp query_received(node_id, ip_port, socket) do
    if node_pid = RoutingTable.get(node_id, ip_port, socket) do
      Node.update(node_pid, :last_query_rcv)
    end
  end

  defp response_received(node_id, ip_port, socket) do
    if node_pid = RoutingTable.get(node_id, ip_port, socket) do
      Node.update(node_pid, :last_response_rcv)
    end
  end

  defp token_match(tok, ip, port, secret, nil) do
    new_str = Utils.tuple_to_ipstr(ip, port) <> secret
    new_tok = :crypto.hash(:sha, new_str)

    tok == new_tok
  end

  defp token_match(tok, ip, port, secret, old_secret) do
    token_match(tok, ip, port, secret, nil) or
    token_match(tok, ip, port, old_secret, nil)
  end



end
