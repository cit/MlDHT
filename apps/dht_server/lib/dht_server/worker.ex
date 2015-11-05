defmodule DHTServer.Worker do
  use GenServer

  require Logger

  alias DHTServer.Utils,     as: Utils

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

        ## Setup RoutingTable
        RoutingTable.node_id(node_id)

        {:ok, %{node_id: node_id, socket: socket, queries: []}}
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

    Search.start_link(:find_node, state[:node_id], state[:node_id], nodes, state[:socket])

    {:noreply, state}
  end

  def handle_cast(:search, state) do
    ## Ubuntu 15.10 (64 bit)
    infohash = "3f19b149f53a50e14fc0b79926a391896eabab6f" |> Hexate.decode
    nodes = RoutingTable.closest_nodes(infohash)

    Search.start_link(:get_peers, state[:node_id], infohash, nodes, state[:socket])

    {:noreply, state}
  end


  def handle_cast(:search2, state) do
    nodes = RoutingTable.closest_nodes(state[:node_id])

    Search.start_link(:find_node, state[:node_id], state[:node_id], nodes, state[:socket])

    {:noreply, state}
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
    payload = KRPCProtocol.encode(:error, code: error.code, msg: error.msg, tid: error.tid)
    :gen_udp.send(state[:socket], ip, port, payload)

    {:noreply, state}
  end

  def handle_message({:ignore, msg}, _socket, _ip, _port, state) do
    Logger.error "Ignore unknown or corrupted message: #{inspect msg}"
    ## Maybe we should blacklist this filthy peer?

    {:noreply, state}
  end


  ########################
  # Incoming DHT Queries #
  ########################

  def handle_message({:ping, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> ping"

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      Node.send_ping_reply(node_pid, remote.tid)
    end

    {:noreply, state}
  end

  def handle_message({:find_node, remote}, socket, ip, port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> find_node"

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      nodes = Enum.map(RoutingTable.closest_nodes(remote.target), fn(pid) ->
        Node.to_tuple(pid)
      end)
      Node.send_find_node_reply(node_pid, remote.tid, nodes)
    end

    {:noreply, state}
  end

  def handle_message({:get_peers, remote}, _socket, _ip, _port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> get_peers (ignore)"

    {:noreply, state}
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

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      Node.response_received(node_pid)
    end

    ## Ping all nodes
    payload = KRPCProtocol.encode(:ping, node_id: state[:node_id])
    Enum.map(remote.nodes, fn(node) ->
      {_id, {ip, port}} = node
      :gen_udp.send(state[:socket], ip, port, payload)
    end)

    {:noreply, state}
  end

  def handle_message({:get_peer_reply, remote}, _socket, _ip, _port, state) do
    Logger.debug "[#{Hexate.encode(remote.node_id)}] >> get_peer_reply"

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

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      Node.response_received(node_pid)
    end

    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################


end
