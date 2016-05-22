defmodule RoutingTable.Search do
  use GenServer

  require Logger

  alias RoutingTable.Distance
  alias RoutingTable.Node
  alias RoutingTable.Search

  def start_link(type, node_id, target, start_nodes, socket, port \\ 0,
                 callback \\ nil) do
    tid  = KRPCProtocol.Encoder.gen_tid
    name = tid_to_process_name(tid)
    args = [type, node_id, target, start_nodes, socket, tid, port, callback]

    GenServer.start_link(__MODULE__, args, name: name)
    name
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def type(node_id) do
    GenServer.call(node_id, :type)
  end

  def callback(pid) do
    GenServer.call(pid, :callback)
  end

  def handle_reply(pid, remote, nodes) do
    GenServer.cast(pid, {:handle_reply, remote, nodes})
  end

  def init([type, node_id, target, start_nodes, socket, tid, port, callback]) do
    nodes = Enum.map(start_nodes, fn(node) ->
      {id, ip, port} = extract_node_infos(node)
      %Search.Node{id: id, ip: ip, port: port}
    end)

    Process.send_after(self(), :search_iterate, 500)

    state = %{
      :type     => type,
      :node_id  => node_id,
      :target   => target,
      :nodes    => nodes,
      :tid      => tid,
      :socket   => socket,
      :port     => port,
      :callback => callback
    }

    {:ok, state}
  end

  def handle_info(:search_iterate, state) do
    if Search.completed?(state.nodes, state.target) do
      Logger.debug "Search is complete"

      ## If the search is complete and it was get_peers search, then we will
      ## send the clostest peers an announce_peer message.
      if state.type == :get_peers and state.port != 0 do
        state.nodes
        |> Distance.closest_nodes(state.target, 7)
        |> Enum.filter(fn(node) -> node.responded == true end)
        |> Enum.each(fn(node) ->
          Logger.debug "[#{Base.encode16 node.id}] << announce_peer"

          ## Generate announce_peer message and sends it
          args = [node_id: state.node_id, info_hash: state.target,
                  token: node.token, port: node.port]
          payload = KRPCProtocol.encode(:announce_peer, args)
          :gen_udp.send(state.socket, node.ip, node.port, payload)
        end)
      end

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

  def handle_call(:callback, _from, state) do
    {:reply, state.callback, state}
  end

  def handle_cast({:handle_reply, remote, nil}, state) do
    old_nodes = update_nodes(state.nodes, remote.node_id, :responded)

    if Map.has_key?(remote, :token) do
      old_nodes = update_nodes(old_nodes, remote.node_id, :token, fn(_) ->
        remote.token
      end)
    end

    state = %{state | nodes: old_nodes}
    {:noreply, state}
  end


  def handle_cast({:handle_reply, remote, nodes}, state) do
    old_nodes = update_nodes(state.nodes, remote.node_id, :responded)

    if Map.has_key?(remote, :token) do
      old_nodes = update_nodes(old_nodes, remote.node_id, :token, fn(_) ->
        remote.token
      end)
    end

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
    Logger.debug "[#{Base.encode16(node.id)}] << #{state.type}"

    payload = gen_request_msg(state.type, state)
    :gen_udp.send(state.socket, node.ip, node.port, payload)

    new_nodes = state.nodes
    |> update_nodes(node.id, :requested, &(&1.requested + 1))
    |> update_nodes(node.id, :request_sent, fn(_) -> :os.system_time(:seconds) end)

    send_queries(rest, %{state | nodes: new_nodes})
  end

  defp gen_request_msg(:find_node, state) do
    args = [tid: state.tid, node_id: state.node_id, target: state.target]
    KRPCProtocol.encode(:find_node, args)
  end

  defp gen_request_msg(:get_peers, state) do
    args = [tid: state.tid, node_id: state.node_id, info_hash: state.target]
    KRPCProtocol.encode(:get_peers, args)
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

  def tid_to_process_name(tid), do: tid_to_process_name(tid, "search")

  def tid_to_process_name("", result), do: String.to_atom(result)

  def tid_to_process_name(tid, result) do
    <<oct :: size(8), rest :: binary>> = tid
    tid_to_process_name(rest, result <> "#{oct}")
  end


end
