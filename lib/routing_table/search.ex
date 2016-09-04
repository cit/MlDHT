defmodule RoutingTable.Search do
  @moduledoc false

  @typedoc """
  A transaction_id (tid) is a two bytes binary.
  """
  @type transaction_id :: <<_::16>>

  @typedoc """
  A DHT search is divided in a :get_peers or a :find_node search.
  """
  @type search_type :: :get_peers | :find_node

  use GenServer

  require Logger

  alias RoutingTable.Distance
  alias RoutingTable.Node
  alias RoutingTable.Search

  ##############
  # Client API #
  ##############

  def start_link(socket, node_id) do
    tid  = KRPCProtocol.gen_tid
    name = tid_to_process_name(tid)

    GenServer.start_link(__MODULE__, [socket, node_id, tid], name: name)
    name
  end

  def get_peers(pid, args), do: GenServer.cast(pid, {:get_peers, args})

  def find_node(pid, args), do: GenServer.cast(pid, {:find_node, args})

  def stop(pid), do: GenServer.call(pid, :stop)

  def type(pid), do: GenServer.call(pid, :type)

  def handle_reply(pid, remote, nodes) do
    GenServer.cast(pid, {:handle_reply, remote, nodes})
  end

  @doc """
  Returns `true` if there is an active search process with a given `tid`.
  Returns `false` if the `tid` is not registerted.
  """
  @spec is_active?(transaction_id | atom) :: boolean
  def is_active?(tid) when is_binary(tid) do
    active? = tid
    |> tid_to_process_name
    |> Process.whereis

    if active?, do: true, else: false
  end

  def is_active?(tid) when is_atom(tid) do
    if Process.whereis(tid), do: true, else: false
  end

  @doc """
  Converts a `tid` to a process name.
  """
  @spec tid_to_process_name(transaction_id) :: atom

  def tid_to_process_name(tid), do: tid_to_process_name(tid, "search")
  def tid_to_process_name("", result) do
    String.replace_trailing(result, "_", "")
    |> String.to_atom
  end
  def tid_to_process_name(tid, result) do
    <<oct :: size(8), rest :: binary>> = tid
    tid_to_process_name(rest, result <> "#{oct}_")
  end

  ####################
  # Server Callbacks #
  ####################

  def init([socket, node_id, tid]) do
    {:ok, %{:socket => socket, :node_id => node_id, :tid => tid}}
  end

  def handle_info(:search_iterate, state) do
    if search_completed?(state.nodes, state.target) do
      Logger.debug "Search is complete"

      ## If the search is complete and it was get_peers search, then we will
      ## send the clostest peers an announce_peer message.
      if Map.has_key?(state, :announce) and state.announce == true do
        send_announce_msg(state)
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

  def handle_cast({:get_peers, args}, state) do
    new_state = start_search_closure(:get_peers, args, state).()

    {:noreply, new_state}
  end

  def handle_cast({:find_node, args}, state) do
    new_state = start_search_closure(:find_node, args, state).()

    {:noreply, new_state}
  end

  def handle_cast({:handle_reply, remote, nil}, state) do
    old_nodes = update_responded_node(state.nodes, remote)

    ## If the reply contains values we need to inform the user of this
    ## information and call the callback function.
    if remote.values, do: Enum.each(remote.values, state.callback)

    state = %{state | nodes: old_nodes}
    {:noreply, state}
  end

  def handle_cast({:handle_reply, remote, nodes}, state) do
    old_nodes = update_responded_node(state.nodes, remote)

    new_nodes = Enum.map(nodes, fn(node) ->
      {id, {ip, port}} = node
      unless Enum.find(state.nodes, fn(x) -> x.id == id end) do
        %Search.Node{id: id, ip: ip, port: port}
      end
    end)
    |> Enum.filter(fn(x) -> x != nil end)

    {:noreply, %{state | nodes: old_nodes ++ new_nodes}}
  end

  #####################
  # Private Functions #
  #####################

  def send_announce_msg(state) do
    state.nodes
    |> Distance.closest_nodes(state.target, 7)
    |> Enum.filter(fn(node) -> node.responded == true end)
    |> Enum.each(fn(node) ->
      Logger.debug "[#{Base.encode16 node.id}] << announce_peer"

      args = [node_id: state.node_id, info_hash: state.target,
              token: node.token, port: node.port]
      args = if state.port == 0, do: args ++ [implied_port: true], else: args

      payload = KRPCProtocol.encode(:announce_peer, args)
      :gen_udp.send(state.socket, node.ip, node.port, payload)
    end)
  end

  ## This function merges args (keyword list) with the state map and returns a
  ## function depending on the type (:get_peers, :find_node).
  defp start_search_closure(type, args, state) do
    fn() ->
      Process.send_after(self(), :search_iterate, 500)

      ## Convert the keyword list to a map and merge it with state.
      args
      |> Enum.into(%{})
      |> Map.merge(state)
      |> Map.put(:type, type)
      |> Map.put(:nodes, nodes_to_search_nodes(args[:start_nodes]))
    end
  end

  defp send_queries([], state), do: state
  defp send_queries([node | rest], state) do
    Logger.debug "[#{Base.encode16(node.id)}] << #{state.type}"

    payload = gen_request_msg(state.type, state)
    :gen_udp.send(state.socket, node.ip, node.port, payload)

    new_nodes = state.nodes
    |> update_nodes(node.id, :requested, &(&1.requested + 1))
    |> update_nodes(node.id, :request_sent, fn(_) -> :os.system_time(:seconds) end)

    send_queries(rest, %{state | nodes: new_nodes})
  end

  defp nodes_to_search_nodes(nodes) do
    Enum.map(nodes, fn(node) ->
      {id, ip, port} = extract_node_infos(node)
      %Search.Node{id: id, ip: ip, port: port}
    end)
  end

  defp gen_request_msg(:find_node, state) do
    args = [tid: state.tid, node_id: state.node_id, target: state.target]
    KRPCProtocol.encode(:find_node, args)
  end

  defp gen_request_msg(:get_peers, state) do
    args = [tid: state.tid, node_id: state.node_id, info_hash: state.target]
    KRPCProtocol.encode(:get_peers, args)
  end

  ## It is necessary that we need to know which node in our node list has
  ## responded. This function goes through the node list and sets :responded of
  ## the responded node to true. If the reply from the remote node also contains
  ## a token this function updates this too.
  defp update_responded_node(nodes, remote) do
    node_list = update_nodes(nodes, remote.node_id, :responded)

    if Map.has_key?(remote, :token) do
      update_nodes(node_list, remote.node_id, :token, fn(_) -> remote.token end)
    else
      node_list
    end
  end

  ## This function is a helper function to update the node list easily.
  defp update_nodes(nodes, node_id, key) do
    update_nodes(nodes, node_id, key, fn(_) -> true end)
  end

  defp update_nodes(nodes, node_id, key, func) do
    Enum.map(nodes, fn(node) ->
      if node.id == node_id do
        Map.put(node, key, func.(node))
      else
        node
      end
    end)
  end

  defp extract_node_infos(node) when is_tuple(node), do: node
  defp extract_node_infos(node) when is_pid(node) do
    Node.to_tuple(node)
  end

  ## This function contains the condition when a search is completed.
  defp search_completed?(nodes, target) do
    nodes
    |> Distance.closest_nodes(target, 7)
    |> Enum.all?(fn(node) ->
      node.responded == true or node.requested >= 3
    end)
  end

end
