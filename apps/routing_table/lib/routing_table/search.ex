defmodule RoutingTable.Search do
  use GenServer

  require Logger

  alias RoutingTable.Distance
  alias RoutingTable.Node
  alias RoutingTable.Search

  def start_link(type, node_id, target, start_nodes, socket) do
    tid  = KRPCProtocol.Encoder.gen_tid
    name = tid_to_process_name(tid)

    GenServer.start_link(__MODULE__, [type, node_id, target,
                                      start_nodes, socket, tid], name: name)
    name
  end

  def stop(node_id) do
    GenServer.call(node_id, :stop)
  end

  def type(node_id) do
    GenServer.call(node_id, :type)
  end

  def handle_reply(pid, remote, nodes) do
    GenServer.cast(pid, {:handle_reply, remote, nodes})
  end

  def init([type, node_id, target, start_nodes, socket, tid]) do
    nodes = Enum.map(start_nodes, fn(node) ->
      {id, ip, port} = extract_node_infos(node)
      %Search.Node{id: id, ip: ip, port: port}
    end)

    Process.send_after(self(), :search_iterate, 500)

    state = %{
      :type    => type,
      :node_id => node_id,
      :target  => target,
      :nodes   => nodes,
      :tid     => tid,
      :socket  => socket
    }

    {:ok, state}
  end


  def handle_info(:search_iterate, state) do
    if Search.completed?(state.nodes, state.target) do
      Logger.debug "Search is complete"
      {:stop, :normal, state}
    else
      ## Send queries to the 3 closest nodes
      new_state = state.nodes
      |> Distance.closest_nodes(state.target)
      |> Enum.filter(fn(x) ->
        x.responded == false and
        x.requested < 3 and
        Search.Node.last_time_requested(x) > 5
      end)
      |> Enum.slice(0..2)
      |> send_queries(state)

      ## Restart Timer
      Process.send_after(self(), :search_iterate, 1_000)

      {:noreply, new_state}
    end
  end


  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:type, _from, state) do
    {:reply, state.type, state}
  end

  def handle_cast({:handle_reply, remote, nil}, state) do
    state = %{state | nodes: update_nodes(state.nodes, remote.node_id,:responded)}
    {:noreply, state}
  end


  def handle_cast({:handle_reply, remote, nodes}, state) do
    old_nodes = update_nodes(state.nodes, remote.node_id, :responded)

    new_nodes = Enum.map(nodes, fn(node) ->
      {id, {ip, port}} = node
      unless Enum.find(state.nodes, fn(x) -> x.id == id end) do
        %Search.Node{id: id, ip: ip, port: port}
      end
    end)
    |> Enum.filter(fn(x) -> x != nil end)

    {:noreply, %{state | nodes: old_nodes ++ new_nodes}}
  end


  def send_queries(state), do: send_queries(state.nodes, state)

  def send_queries([], state), do: state

  def send_queries([node | rest], state) do
    Logger.debug "[#{Hexate.encode(node.id)}] << #{state.type}"

    payload = gen_request_msg(state.type, state)
    :gen_udp.send(state.socket, node.ip, node.port, payload)

    new_nodes = state.nodes
    |> update_nodes(node.id, :requested, &(&1.requested + 1))
    |> update_nodes(node.id, :request_sent, fn(_) -> :os.system_time(:seconds) end)

    send_queries(rest, %{state | nodes: new_nodes})
  end

  defp gen_request_msg(:find_node, state) do
    KRPCProtocol.encode(:find_node, tid: state.tid, node_id: state.node_id,
                        target: state.target)
  end

  defp gen_request_msg(:get_peers, state) do
    KRPCProtocol.encode(:get_peers, tid: state.tid, node_id: state.node_id,
                        info_hash: state.target)
  end


  def update_nodes(nodes, node_id, key) do
    update_nodes(nodes, node_id, key, fn(_) -> true end)
  end

  def update_nodes(nodes, node_id, key, func) do
    Enum.map(nodes, fn(node) ->
      if node.id == node_id do
        Map.put(node, key, func.(node))
      else
        node
      end
    end)
  end


  def extract_node_infos(node) when is_tuple(node), do: node

  def extract_node_infos(node) when is_pid(node) do
    Node.to_tuple(node)
  end

  def completed?(nodes, target) do
    nodes
    |> Distance.closest_nodes(target, 7)
    |> Enum.all?(fn(node) ->
      node.responded == true or node.requested >= 3
    end)
  end

  def is_active?(tid) do
    tid
    |> tid_to_process_name
    |> Process.whereis
  end

  def tid_to_process_name(tid) do
    <<oct1 :: size(8), oct2 :: size(8)>> = tid
    String.to_atom("search#{oct1}#{oct2}")
  end


end
