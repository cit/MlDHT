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
    GenServer.call(@name, :bootstrap)
  end

  def init([]), do: init([port: 0])

  def init(port: port) do
    case :gen_udp.open port, [{:active, true}] do
      {:ok, socket} ->
        node_id = Hexate.decode("fc8a15a2faf2734dbb1dc5f7afdc5c9beaeb1f59")
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


  def handle_call(:bootstrap, _from, state) do
    payload = KRPCProtocol.encode(:ping, node_id: state[:node_id])
    :gen_udp.send(state[:socket], {67, 215, 246, 10}, 6881, payload)

    {:reply, :ok, state}
  end

  def handle_info({:udp, socket, ip, port, raw_data}, state) do
    # Logger.debug "[#{Utils.tuple_to_ipstr(ip, port)}]\n"
    # <> PrettyHex.pretty_hex(to_string(raw_data))

    foo = raw_data
    |> :binary.list_to_bin
    |> String.rstrip(?\n)

    Logger.debug "BIN: #{inspect foo, limit: 1000}"
    foo
    |> KRPCProtocol.decode
    |> handle_message(socket, ip, port, state)
  end


  ########################
  # Incoming DHT Queries #
  ########################

  def handle_message({:ping, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> ping")

    if node_pid = RoutingTable.get_node(remote.node_id, {ip, port}, socket) do
      Node.send_ping_reply(node_pid)
    end

    {:noreply, state}
  end

  def handle_message({:find_node, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> find_node (ignore)")

    {:noreply, state}
  end

  ########################
  # Incoming DHT Replies #
  ########################

  def handle_message({:error, error}, socket, ip, port, state) do
    Logger.error "[#{__MODULE__}] >> error (#{error.code}: #{error.msg})"

    {:noreply, state}
  end

  def handle_message({:find_node_reply, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> find_node_reply")

    payload = KRPCProtocol.encode(:ping, node_id: state[:node_id])
    Enum.map(remote.nodes, fn(node) ->
      {ip, port} = node
      :gen_udp.send(state[:socket], Utils.ipstr_to_tuple(ip), port, payload)
    end)

    {:noreply, state}
  end

  def handle_message({:ping_reply, remote}, socket, ip, port, state) do
    debug_reply(remote.node_id, ">> ping_reply")

    if node_pid = RoutingTable.get_node(remote.node_id, {ip, port}, socket) do
      Node.update_last_received(node_pid)

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

  def debug_reply(node_id, msg) do
    Logger.debug "[#{__MODULE__}] [#{String.slice(Hexate.encode(node_id), 0, 5)}] #{msg}"
  end

end
