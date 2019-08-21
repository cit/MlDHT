defmodule MlDHT.Server.Worker do
  @moduledoc false

  use GenServer

  require Logger

  alias MlDHT.Server.Utils
  alias MlDHT.Server.Storage
  alias MlDHT.Registry

  alias MlDHT.RoutingTable.Node,   as: Node
  alias MlDHT.RoutingTable.Search, as: Search

  @type ip_vers :: :ipv4 | :ipv6

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:node_id], opts)
  end


  @doc """
  This function takes the bootstrapping nodes from the config and starts a
  find_node search to our own node id. By doing this, we will quickly collect
  nodes that are close to us and save it to our own routing table.

  ## Example
      iex> MlDHT.DHTServer.Worker.bootstrap
  """
  def bootstrap(pid) do
    GenServer.cast(pid, :bootstrap)
  end


  @doc ~S"""
  This function needs an infohash as binary, and a callback function as
  parameter. This function uses its own routing table as a starting point to
  start a get_peers search for the given infohash.

  ## Example
      iex> infohash = "3F19..." |> Base.decode16!
      iex> MlDHT.DHTServer.search(infohash, fn(node) ->
             {ip, port} = node
             IO.puts "ip: #{ip} port: #{port}"
           end)
  """
  def search(pid, infohash, callback) do
    GenServer.cast(pid, {:search, infohash, callback})
  end

  def search_announce(pid, infohash, callback) do
    GenServer.cast(pid, {:search_announce, infohash, callback})
  end

  def search_announce(pid, infohash, port, callback) do
    GenServer.cast(pid, {:search_announce, infohash, port, callback})
  end


  def create_udp_socket(port, ip_vers) do
    ip_addr = ip_vers |> to_string() |> Kernel.<>("_addr") |> String.to_atom()
    options = ip_vers |> inet_option() |> maybe_put(:ip, config(ip_addr))

    case :gen_udp.open(port, options ++ [{:active, true}]) do
      {:ok, socket} ->
        Logger.debug "Init DHT Node (#{ip_vers})"

        foo = :inet.getopts(socket, [:ipv6_v6only])
        Logger.debug "Options: #{inspect foo}"

        socket
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def init(node_id) do
    ## Returns false in case the option is not set in the environment (setting
    ## the option to false or not setting the option at all has the same effect
    ## in this case)
    cfg_ipv6_is_enabled? = config(:ipv6, false)
    cfg_ipv4_is_enabled? = config(:ipv4, false)

    unless cfg_ipv4_is_enabled? or cfg_ipv6_is_enabled? do
      raise "Configuration failure: Either ipv4 or ipv6 has to be set to true."
    end

    cfg_port = config(:port)
    socket   = if cfg_ipv4_is_enabled?, do: create_udp_socket(cfg_port, :ipv4), else: nil
    socket6  = if cfg_ipv6_is_enabled?, do: create_udp_socket(cfg_port, :ipv6), else: nil

    ## Change secret of the token every 5 minutes
    Process.send_after(self(), :change_secret, 60 * 1000 * 5)

    state = %{node_id: node_id, socket: socket, socket6: socket6, old_secret:
              nil, secret: Utils.gen_secret}

    # INFO Setup routingtable for IPv4
    if cfg_ipv4_is_enabled? do
      node_id
      |> start_rtable(:ipv4)
      |> MlDHT.RoutingTable.Worker.node_id(node_id)

      bootstrap(state, {socket, :inet})
    end

    # INFO Setup routingtable for IPv6
    if cfg_ipv6_is_enabled? do
      node_id
      |> start_rtable(:ipv6)
      |> MlDHT.RoutingTable.Worker.node_id(node_id)

      bootstrap(state, {socket6, :inet6})
    end

    {:ok, state}
  end

  defp start_rtable(node_id, rt_name) do
    node_id_enc = node_id |> Base.encode16()
    rt_name = to_string(rt_name)

    ## Allows giving atoms as rt_name to this function, e.g. :ipv4
    {:ok, _pid} = node_id_enc
    |> MlDHT.Registry.get_pid(MlDHT.RoutingTable.Supervisor)
    |> DynamicSupervisor.start_child({
      MlDHT.RoutingTable.Supervisor,
      node_id:     node_id,
      node_id_enc: node_id_enc,
      rt_name:     rt_name})

    node_id |> get_rtable(rt_name)
  end

  defp get_rtable(node_id, rt_name) do
    node_id
    |> Base.encode16()
    |> MlDHT.Registry.get_pid(MlDHT.RoutingTable.Worker, rt_name)
  end

  def handle_cast({:bootstrap, socket_tuple}, state) do
    bootstrap(state, socket_tuple)
    {:noreply, state}
  end

  def handle_cast({:search_announce, infohash, callback}, state) do
    # TODO What about ipv6?
    nodes = state.node_id
    |> get_rtable(:ipv4)
    |> MlDHT.RoutingTable.Worker.closest_nodes(infohash)

    Search.start_link(state.socket, state.node_id)
    |> Search.get_peers(target: infohash, start_nodes: nodes,
    callback: callback, port: 0, announce: true)

    {:noreply, state}
  end

  def handle_cast({:search_announce, infohash, callback, port}, state) do
    nodes = state.node_id
    |> get_rtable(:ipv4)
    |> MlDHT.RoutingTable.Worker.closest_nodes(infohash)

    Search.start_link(state.socket, state.node_id)
    |> Search.get_peers(target: infohash, start_nodes: nodes,
    callback: callback, port: port, announce: true)

    {:noreply, state}
  end

  def handle_cast({:search, infohash, callback}, state) do
    nodes = state.node_id
    |> get_rtable(:ipv4)
    |> MlDHT.RoutingTable.Worker.closest_nodes(infohash)

    Search.start_link(state.socket, state.node_id)
    |> Search.get_peers(target: infohash, start_nodes: nodes, port: 0,
    callback: callback, announce: false)

    {:noreply, state}
  end


  def handle_info(:change_secret, state) do
    Logger.debug "Change Secret"
    {:noreply, %{state | old_secret: state.secret, secret: Utils.gen_secret()}}
  end


  def handle_info({:udp, socket, ip, port, raw_data}, state) do
    # if Mix.env == :dev do
    #   Logger.debug "[#{Utils.tuple_to_ipstr(ip, port)}]\n"
    #   <> PrettyHex.pretty_hex(to_string(raw_data))
    #   Logger.debug "#{inspect raw_data, limit: 1000}"
    # end

    raw_data
    |> :binary.list_to_bin
    |> String.trim_trailing("\n")
    |> KRPCProtocol.decode
    |> handle_message({socket, get_ip_vers(socket)}, ip, port, state)
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

  def handle_message({:invalid, msg}, _socket, _ip, _port, state) do
    Logger.error "Ignore unknown or corrupted message: #{inspect msg, limit: 5000}"
    ## Maybe we should blacklist this filthy peer?

    {:noreply, state}
  end


  ########################
  # Incoming DHT Queries #
  ########################

  def handle_message({:ping, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> ping"
    query_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    send_ping_reply(remote.node_id, remote.tid, ip, port, socket)

    {:noreply, state}
  end


  def handle_message({:find_node, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> find_node"
    query_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    ## Get closest nodes for the requested target from the routing table
    nodes = state.node_id
    |> get_rtable(ip_vers)
    |> MlDHT.RoutingTable.Worker.closest_nodes(remote.target)
    |> Enum.map(fn(pid) ->
      try do
        if Process.alive?(pid) do
          Node.to_tuple(pid)
        end
      rescue
        _e in Enum.EmptyError -> nil
      end
    end)

    if nodes != [] do
      Logger.debug("[#{Base.encode16(remote.node_id)}] << find_node_reply")

      nodes_args = if ip_vers == :ipv4, do: [nodes: nodes], else: [nodes6: nodes]
      args = [node_id: state.node_id] ++ nodes_args ++ [tid: remote.tid]
      Logger.debug "NODES ARGS: #{inspect args}"
      payload = KRPCProtocol.encode(:find_node_reply, args)

      # Logger.debug(PrettyHex.pretty_hex(to_string(payload)))

      :gen_udp.send(socket, ip, port, payload)
    end


    {:noreply, state}
  end


  ## Get_peers
  def handle_message({:get_peers, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> get_peers"
    query_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    ## Generate a token for the requesting node
    token = :crypto.hash(:sha, Utils.tuple_to_ipstr(ip, port) <> state.secret)

    ## Get pid of the storage genserver
    storage_pid = state.node_id |> Base.encode16() |> Registry.get_pid(Storage)

    args =
    if Storage.has_nodes_for_infohash?(storage_pid, remote.info_hash) do
      values = Storage.get_nodes(storage_pid, remote.info_hash)
      [node_id: state.node_id, values: values, tid: remote.tid, token: token]
    else
      ## Get the closest nodes for the requested info_hash
      rtable = state.node_id |> get_rtable(ip_vers)
      nodes = Enum.map(MlDHT.RoutingTable.Worker.closest_nodes(rtable, remote.info_hash), fn(pid) ->
        Node.to_tuple(pid)
      end)

      Logger.debug("[#{Base.encode16(remote.node_id)}] << get_peers_reply (nodes)")
      [node_id: state.node_id, nodes: nodes, tid: remote.tid, token: token]
    end

    payload = KRPCProtocol.encode(:get_peers_reply, args)
    :gen_udp.send(socket, ip, port, payload)

    {:noreply, state}
  end

  ## Announce_peer
  def handle_message({:announce_peer, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> announce_peer"
    query_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    if token_match(remote.token, ip, port, state.secret, state.old_secret) do
      Logger.debug "Valid Token"
      Logger.debug "#{inspect remote}"

      port = if Map.has_key?(remote, :implied_port) do port else remote.port end

      ## Get pid of the storage genserver
      storage_pid = state.node_id |> Base.encode16() |> Registry.get_pid(Storage)

      Storage.put(storage_pid, remote.info_hash, ip, port)

      ## Sending a ping_reply back as an acknowledgement
      send_ping_reply(remote.node_id, remote.tid, ip, port, socket)

      {:noreply, state}
    else
      Logger.debug("[#{Base.encode16(remote.node_id)}] << error (invalid token})")

      args = [code: 203, msg: "Announce_peer with wrong token", tid: remote.tid]
      payload = KRPCProtocol.encode(:error, args)
      :gen_udp.send(socket, ip, port, payload)

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

  def handle_message({:find_node_reply, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> find_node_reply"
    response_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    pname = Search.tid_to_process_name(remote.tid)
    if Search.is_active?(remote.tid) do
      ## If this belongs to an active search, it is actual a get_peers_reply
      ## without a token.
      if Search.type(pname) == :get_peers do
        handle_message({:get_peer_reply, remote}, {socket, ip_vers}, ip, port, state)
      else
        Search.handle_reply(pname, remote, remote.nodes)
      end
    end

    ## Ping all nodes
    payload = KRPCProtocol.encode(:ping, node_id: state.node_id)
    Enum.map(remote.nodes, fn(node_tuple) ->
      {_id, {ip, port}} = node_tuple
      :gen_udp.send(socket, ip, port, payload)
    end)

    {:noreply, state}
  end

  def handle_message({:get_peer_reply, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> get_peer_reply"
    response_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    pname = Search.tid_to_process_name(remote.tid)
    if Search.is_active?(remote.tid) do
      Search.handle_reply(pname, remote, remote.nodes)
    end

    {:noreply, state}
  end

  def handle_message({:ping_reply, remote}, {socket, ip_vers}, ip, port, state) do
    Logger.debug "[#{Base.encode16(remote.node_id)}] >> ping_reply"
    response_received(remote.node_id, state.node_id, {ip, port}, {socket, ip_vers})

    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################

  def inet_option(:ipv4), do: [:inet]
  def inet_option(:ipv6), do: [:inet6, {:ipv6_v6only, true}]

  def maybe_put(list, name, nil), do: list
  def maybe_put(list, name, value), do: list ++ [{name, value}]

  def config(value, ret \\ nil), do: Application.get_env(:mldht, value, ret)

  ## This function starts a search with the bootstrapping nodes.
  defp bootstrap(state, {socket, inet}) do

    ## Get the nodes which are defined as bootstrapping nodes in the config
    nodes = config(:bootstrap_nodes)
    |> resolve_hostnames(inet)

    Logger.debug "nodes: #{inspect nodes}"

    ## Start a find_node search to collect neighbors for our routing table
    Search.start_link(socket, state.node_id)
    |> Search.find_node(target: state.node_id, start_nodes: nodes)
  end

  ## function iterates over a list of bootstrapping nodes and tries to
  ## resolve the hostname of each node. If a node is not resolvable the function
  ## removes it; if is resolvable it replaces the hostname with the IP address.
  defp resolve_hostnames(list, inet), do: resolve_hostnames(list, inet, [])
  defp resolve_hostnames([], _inet, result), do: result
  defp resolve_hostnames([node_tuple | tail], inet, result) do
    {id, host, port} = node_tuple

    case :inet.getaddr(String.to_charlist(host), :inet) do
      {:ok, ip_addr}  ->
        resolve_hostnames(tail, inet, result ++ [{id, ip_addr, port}])
      {:error, code} ->
        Logger.error "Couldn't resolve the hostname: #{host} (reason: #{code})"
        resolve_hostnames(tail, inet, result)
    end
  end

  ## Gets a socket as an argument and returns to which ip version (:ipv4 or
  ## :ipv6) the socket belongs.
  @spec get_ip_vers(port) :: ip_vers
  defp get_ip_vers(socket) when is_port(socket) do
    case :inet.getopts(socket, [:ipv6_v6only]) do
      {:ok, [ipv6_v6only: true]} -> :ipv6
      {:ok, []}                  -> :ipv4
    end
  end

  defp send_ping_reply(node_id, tid, ip, port, socket) do
    Logger.debug("[#{Base.encode16(node_id)}] << ping_reply")

    payload = KRPCProtocol.encode(:ping_reply, tid: tid, node_id: node_id)
    :gen_udp.send(socket, ip, port, payload)
  end


  defp query_received(remote_node_id, own_node_id, ip_port, {socket, ip_vers}) do
    # TODO: node_id is not the own but the peer's node_id
    rtable = own_node_id |> get_rtable(ip_vers)

    if node_pid = MlDHT.RoutingTable.Worker.get(rtable, remote_node_id) do
      Node.update(node_pid, :last_query_rcv)
    else
      MlDHT.RoutingTable.Worker.add(rtable, remote_node_id, ip_port, socket)
    end
  end

  defp response_received(remote_node_id, own_node_id, ip_port, {socket, ip_vers}) do
    # TODO: node_id is not the own but the peer's node_id
    rtable = own_node_id |> get_rtable(ip_vers)
    if node_pid = MlDHT.RoutingTable.Worker.get(rtable, remote_node_id) do
      Node.update(node_pid, :last_response_rcv)
    else
      MlDHT.RoutingTable.Worker.add(rtable, remote_node_id, ip_port, socket)
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
