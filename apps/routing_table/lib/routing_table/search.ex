defmodule RoutingTable.Search do
  use GenServer

  require Logger
  require Bitwise

  alias RoutingTable.Distance, as: Distance

  def start_link(own_node_id, target, start_nodes, socket) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [own_node_id, target, start_nodes, socket])
    pid
  end

  def start(pid) do
    GenServer.cast(pid, :start)
  end

  def stop(node_id) do
    GenServer.call(node_id, :stop)
  end

  def tid(pid) do
    GenServer.call(pid, :tid)
  end

  def reply(pid, remote, nodes) do
    GenServer.cast(pid, {:reply, remote, nodes})
  end

  def completed?(pid) do
    GenServer.call(pid, :completed?)
  end


  def init([own_node_id, target, start_nodes, socket]) do
    nodes = Enum.map(start_nodes, fn(node_pid) ->
      {id, ip, port} = RoutingTable.Node.to_tuple(node_pid)
      %{id: id, ip: ip, port: port, requested: false, responded: false}
    end)

    state = %{
      :own_node_id => own_node_id,
      :target      => target,
      :nodes       => nodes,
      :tid         => KRPCProtocol.Encoder.gen_tid,
      :socket      => socket
    }

    {:ok, state}
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:tid, _from, state) do
    {:reply, state.tid, state}
  end

  def handle_call(:completed?, _from, state) do
    completed = state.nodes
    |> Distance.closest_nodes(state.target, 7)
    |> Enum.all?(fn(node) ->
      node.requested == true and node.responded == true
    end)

    # Logger.debug "#{inspect state.nodes}"

    {:reply, completed, state}
  end

  def handle_cast(:start, state) do
    new_state = send_queries(state)

    {:noreply, new_state}
  end

  def handle_cast({:reply, remote, nil}, state) do
    state = %{state | nodes: update_nodes(state.nodes, remote.node_id, :responded)}
    {:noreply, state}
   end

  def handle_cast({:reply, remote, nodes}, state) do
    old_nodes = update_nodes(state.nodes, remote.node_id, :responded)

    new_nodes = Enum.map(nodes, fn(node) ->
      {id, {ip, port}} = node
      unless Enum.find(state.nodes, fn(x) -> x.id == id end) do
        %{id: id, ip: ip, port: port, requested: false, responded: false}
      end
    end) |> Enum.filter(fn(x) -> x != nil end)

    new_state = %{state | nodes: old_nodes ++ new_nodes}

    new_state = new_state.nodes
    |> Enum.sort(fn(x, y) -> Distance.xor_cmp(x.id, y.id, state.target, &(&1 < &2)) end)
    |> Enum.filter(fn(x) -> x.requested == false end)
    |> Enum.slice(0..2)
    |> send_queries(new_state)

    {:noreply, new_state}
  end


  def send_queries([], state), do: state
  def send_queries(state), do: send_queries(state.nodes, state)
  def send_queries([node | rest], state) do
    Logger.debug "[#{Hexate.encode(node.id)}] << get_peers"

    payload = KRPCProtocol.encode(:get_peers, tid: state.tid,
                                  node_id: state.own_node_id,
                                  info_hash: state.target)
    :gen_udp.send(state.socket, node.ip, node.port, payload)
    new_nodes = update_nodes(state.nodes, node.id, :requested)

    send_queries(rest, %{state | nodes: new_nodes})
  end


  def update_nodes(nodes, node_id, key) do
    Enum.map(nodes, fn(x) ->
      if x.id == node_id do
        Map.put(x, key, true)
      else
        x
      end
    end)
  end

end
