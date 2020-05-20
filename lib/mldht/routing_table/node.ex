defmodule MlDHT.RoutingTable.Node do
  @moduledoc false

  use GenServer, restart: :temporary

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [opts])
  end

  @doc """
  Stops the registry.
  """
  def stop(node_id) do
    GenServer.call(node_id, :stop)
  end

  def id(pid) do
    GenServer.call(pid, :id)
  end

  def socket(pid) do
    GenServer.call(pid, :socket)
  end

  def bucket_index(pid), do: GenServer.call(pid, :bucket_index)
  def bucket_index(pid, new_index) do
    GenServer.cast(pid, {:bucket_index, new_index})
  end

  def goodness(pid) do
    GenServer.call(pid, :goodness)
  end

  def goodness(pid, goodness) do
    GenServer.call(pid, {:goodness, goodness})
  end

  def is_good?(pid) do
    GenServer.call(pid, :is_good?)
  end

  def is_questionable?(pid) do
    GenServer.call(pid, :is_questionable?)
  end

  def send_find_node(node_id, target) do
    GenServer.cast(node_id, {:send_find_node, target})
  end

  def send_ping(pid) do
    GenServer.cast(pid, :send_ping)
  end

  def send_find_node_reply(pid, tid, nodes) do
    GenServer.cast(pid, {:send_find_node_reply, tid, nodes})
  end

  def send_get_peers_reply(pid, tid, nodes, token) do
    GenServer.cast(pid, {:send_get_peers_reply, tid, nodes, token})
  end

  def response_received(pid) do
    GenServer.cast(pid, {:response_received})
  end

  def query_received(pid) do
    GenServer.cast(pid, {:query_received})
  end

  def last_time_responded(pid) do
    GenServer.call(pid, :last_time_responded)
  end

  def last_time_queried(pid) do
    GenServer.call(pid, :last_time_queried)
  end

  def to_tuple(pid) do
    GenServer.call(pid, :to_tuple)
  end

  def to_string(pid) do
    GenServer.call(pid, :to_string)
  end

  ###
  ## GenServer API
  ###

  def init([opts]) do
    {node_id, {ip, port}, socket} = opts[:node_tuple]

    {:ok,
     %{
       :own_node_id  => opts[:own_node_id],
       :bucket_index => opts[:bucket_index],
       :node_id      => node_id,
       :ip           => ip,
       :port         => port,
       :socket       => socket,
       :goodness     => :good,

       ## Timer
       :last_response_rcv => :os.system_time(:millisecond),
       :last_query_rcv    => 0,
       :last_query_snd    => 0
     }
    }
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(:id, _from, state) do
    {:reply, state.node_id, state}
  end

  def handle_call(:bucket_index, _from, state) do
    {:reply, state.bucket_index, state}
  end

  def handle_call(:socket, _from, state) do
    {:reply, state.socket, state}
  end

  def handle_call(:goodness, _from, state) do
    {:reply, state.goodness, state}
  end

  def handle_call(:is_good?, _from, state) do
    {:reply, state.goodness == :good, state}
  end

  def handle_call(:is_questionable?, _from, state) do
    {:reply, state.goodness == :questionable, state}
  end

  def handle_call({:goodness, goodness}, _from, state) do
    {:reply, :ok, %{state | :goodness => goodness}}
  end

  def handle_call(:last_time_responded, _from, state) do
    {:reply, :os.system_time(:millisecond) - state.last_response_rcv, state}
  end

  def handle_call(:last_time_queried, _from, state) do
    {:reply, state.last_query_snd, state}
  end

  def handle_call(:to_tuple, _from, state) do
    {:reply, {state.node_id, state.ip, state.port}, state}
  end

  def handle_call(:to_string, _from, state) do
    node_id = Base.encode16(state.node_id)
    str     = "#Node<id: #{node_id}, goodness: #{state.goodness}>"

    {:reply, str, state}
  end

  # If we receive a response to our query and the goodness value is
  # :questionable, we set it back to :good
  def handle_cast({:response_received}, state) do
    {:noreply, %{state | :last_response_rcv => :os.system_time(:millisecond),
                         :goodness => :good}}
  end

  def handle_cast({:query_received}, state) do
    {:noreply, %{state | :last_query_rcv => :os.system_time(:millisecond)}}
  end

  def handle_cast({:bucket_index, new_index}, state) do
    {:noreply, %{state | :bucket_index => new_index}}
  end

  ###########
  # Queries #
  ###########

  def handle_cast(:send_ping, state) do
    Logger.debug("[#{Base.encode16(state.node_id)}] << ping")

    payload = KRPCProtocol.encode(:ping, node_id: state.own_node_id)
    :gen_udp.send(state.socket, state.ip, state.port, payload)

    {:noreply, %{state | :last_query_snd => :os.system_time(:millisecond)}}
  end

  def handle_cast({:send_find_node, target}, state) do
    Logger.debug("[#{Base.encode16(state.node_id)}] << find_node")

    payload = KRPCProtocol.encode(:find_node, node_id: state.own_node_id,
                                  target: target)
    :gen_udp.send(state.socket, state.ip, state.port, payload)

    {:noreply, %{state | :last_query_snd => :os.system_time(:millisecond)}}
  end

  ###########
  # Replies #
  ###########

  def handle_cast({:send_find_node_reply, tid, nodes}, state) do
    Logger.debug("[#{Base.encode16(state.node_id)}] << find_node_reply")

    payload = KRPCProtocol.encode(:find_node_reply, node_id:
                                  state.own_node_id, nodes: nodes, tid: tid)
    :gen_udp.send(state.socket, state.ip, state.port, payload)

    {:noreply, state}
  end

  def handle_cast({:send_get_peers_reply, tid, nodes, token}, state) do
    Logger.debug("[#{Base.encode16(state.node_id)}] << get_peers_reply (#{inspect token})")

    payload = KRPCProtocol.encode(:get_peers_reply, node_id:
                                  state.own_node_id, nodes: nodes, tid: tid, token: token)
    :gen_udp.send(state.socket, state.ip, state.port, payload)

    {:noreply, state}
  end

end
