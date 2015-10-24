defmodule RoutingTable.Search do
  use GenServer

  require Logger
  require Bitwise

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
    foo = closest_nodes(state.nodes, state.target, 7)
    completed = Enum.all?(foo, fn(node) ->
      node.requested == true and node.responded == true
    end)

    Logger.debug "check completed #{inspect foo} (#{inspect completed})"


    {:reply, completed, state}
  end

  def handle_cast(:start, state) do
    new_state = send_queries(state)

    {:noreply, new_state}
  end

   def handle_cast({:reply, remote, nil}, state) do
    nodes = Enum.map(state.nodes, fn(x) ->
    if x.id == remote.node_id do
      Logger.error "#{Hexate.encode remote.node_id} responded"
        %{x | responded: true}
      else
        x
      end
     end)

    {:noreply, %{state | nodes: nodes}}
   end

  def handle_cast({:reply, remote, nodes}, state) do
    old_nodes = Enum.map(state.nodes, fn(x) ->
    if x.id == remote.node_id do
      Logger.error "#{Hexate.encode remote.node_id} responded"
        %{x | responded: true}
      else
        x
      end
    end)

    new_nodes = Enum.map(nodes, fn(node) ->
      {id, {ip, port}} = node

      unless Enum.find(state.nodes, fn(x) -> x.id == id end) do
        %{id: id, ip: ip, port: port, requested: false, responded: false}
      end
    end) |> Enum.filter(fn(x) -> x != nil end)

    Logger.error "#{inspect new_nodes}"

    new_state = %{state | nodes: old_nodes ++ new_nodes}

    output = Enum.sort(new_state.nodes, fn(x, y) -> xor_compare(x.id, y.id, state.target, &(&1 < &2)) end)
    |> Enum.filter(fn(x) -> x.requested == false end)
    |> Enum.slice(0..2)

    new_state = send_queries(output, new_state)

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

    new_nodes = Enum.map(state.nodes, fn(n) ->
      if n.id == node.id do
        %{n | requested: true}
      else
        n
      end
    end)

    send_queries(rest, %{state | nodes: new_nodes})
  end


  def closest_nodes(nodes, target, n) do
    Enum.sort(nodes, fn(x, y) ->
      xor_compare(x.id, y.id, target, &(&1 < &2))
    end)
    |> Enum.slice(0..n)
  end

  def xor_compare("", "", "", func), do: func.(0, 0)
  def xor_compare(node_id_a, node_id_b, target, func) do
    << byte_a      :: 8, rest_a      :: bitstring >> = node_id_a
    << byte_b      :: 8, rest_b      :: bitstring >> = node_id_b
    << byte_target :: 8, rest_target :: bitstring >> = target

    if (byte_a == byte_b) do
      xor_compare(rest_a, rest_b, rest_target, func)
    else
      xor_a = Bitwise.bxor(byte_a, byte_target)
      xor_b = Bitwise.bxor(byte_b, byte_target)

      func.(xor_a, xor_b)
    end

  end


end
