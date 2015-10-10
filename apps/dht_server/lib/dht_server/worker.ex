defmodule DHTServer.Worker do
  use GenServer

  require Logger

  alias DHTServer.Utils,     as: Utils

  alias RoutingTable.Node,   as: Node
  alias RoutingTable.Worker, as: RoutingTable

  @name __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: @name)
  end

  def bootstrap do
    GenServer.cast(@name, :bootstrap)
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

        ## start bucket manager genserver
        RoutingTable.node_id(node_id)
        RoutingTable.print

        {:ok, [node_id: node_id, socket: socket]}
      {:error, reason} ->
        {:stop, reason}
    end
  end


  def handle_cast(:bootstrap, state) do
    cfg = Application.get_all_env(:dht_server)

    Enum.each(cfg[:bootstrap_nodes], fn(node) ->
      {host, port} = node

      case :inet.getaddr(String.to_char_list(host), :inet) do
        {:ok, ip_addr} ->
          payload = KRPCProtocol.encode(:ping, node_id: state[:node_id])
          :gen_udp.send(state[:socket], ip_addr, port, payload)
        {:error, code} ->
          Logger.error "Couldn't resolve the hostname #{host}: #{inspect code}"
      end
    end)

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


  ########################
  # Incoming DHT Queries #
  ########################

  def handle_message({:ping, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> ping")

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      Node.send_ping_reply(node_pid)
    end

    {:noreply, state}
  end

  def handle_message({:find_node, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> find_node (ignore)")

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      nodes = Enum.map(RoutingTable.closest_nodes(remote.target), fn(pid) ->
        Node.to_tuple(pid)
      end)
      Logger.debug "#{inspect nodes}"
      Node.send_find_node_reply(node_pid, nodes)
    end

    {:noreply, state}
  end

  def handle_message({:get_peers, remote}, _socket, _ip, _port, state) do
    debug_reply(remote.node_id, ">> get_peers (ignore)")

    {:noreply, state}
  end

  ########################
  # Incoming DHT Replies #
  ########################

  def handle_message({:error, error}, _socket, _ip, _port, state) do
    Logger.error "[#{__MODULE__}] >> error (#{error.code}: #{error.msg})"

    {:noreply, state}
  end

  def handle_message({:find_node_reply, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> find_node_reply")

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      Node.response_received(node_pid)
    end

    payload = KRPCProtocol.encode(:ping, node_id: state[:node_id])
    Enum.map(remote.nodes, fn(node) ->
      {ip, port} = node
      :gen_udp.send(state[:socket], Utils.ipstr_to_tuple(ip), port, payload)
    end)

    {:noreply, state}
  end

  def handle_message({:ping_reply, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> ping_reply")

    if node_pid = RoutingTable.get(remote.node_id, {ip, port}, socket) do
      Node.response_received(node_pid)

      ## If we have less than 10 nodes in our routing table lets ask node for
      ## some close nodes
      if RoutingTable.size < 10 do
        Node.send_find_node(node_pid, state[:node_id])
      end
    end

    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################

  # def find_node(target) do
  #   Enum.map(RoutingTable.closest_nodes(remote.target), fn(pid) ->
  #       Node.to_tuple(pid)
  #     end)
  # end


  def debug_reply(node_id, msg) do
    Logger.debug "[#{String.slice(Hexate.encode(node_id), 0, 5)}] #{msg}"
  end

end
