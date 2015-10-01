defmodule RoutingTable.Node do
  use GenServer

  ## 5 Minutes
  @review_time 300_000

  require Logger

  def start_link(own_node_id, node_tuple) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [own_node_id, node_tuple])
    pid
  end

  @doc """
  Stops the registry.
  """
  def stop(node_id) do
    GenServer.call(node_id, :stop)
  end

  def find_node(node_id, target) do
    GenServer.call(node_id, {:find_node, target})
  end

  def send_ping_reply(node_id) do
    GenServer.call(node_id, :send_ping_reply)
  end

  def review(node_id) do
    GenServer.call(node_id, :review)
  end


  def update_last_received(node_id) do
    GenServer.call(node_id, :update_last_received)
  end

  ###
  ## GenServer API
  ###

  def init([own_node_id, node_tuple]) do
    Logger.debug "Init Node #{inspect self()}"
    {node_id, {ip, port}, socket} = node_tuple

    RoutingTable.Timer.start_link(self(), :review, @review_time)

    {:ok, %{
        :own_node_id   => own_node_id,
        :node_id       => node_id,
        :ip            => ip,
        :port          => port,
        :socket        => socket,
        :goodness      => :good,
        :last_received => :os.system_time(:seconds)
        }
    }
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_info(:review, state) do
    Logger.debug("[#{Hexate.encode(state[:node_id])}] review")

    case (:os.system_time(:seconds) - state[:last_received]) do
      time when time >= 0 and time <= 500  -> ## 5 Minutes
        Logger.debug("[#{Hexate.encode(state[:node_id])}] idle 5 minutes")
        Logger.debug("[#{Hexate.encode(state[:node_id])}] << ping")

        payload = KRPCProtocol.encode(:ping, node_id: state[:node_id])
        :gen_udp.send(state[:socket], state[:ip], state[:port], payload)
      time when time > 500 and time <= 700  -> ## 5 Minutes
        Logger.error "BAD NODE!!!1!"
    end

    ## Start a new timer
    RoutingTable.Timer.start_link(self(), :review, @review_time)

    {:noreply, state}
  end


  def handle_info({:ping, node_id}, state) do
    Logger.debug("[#{Hexate.encode(state[:node_id])}] << ping")

    payload = KRPCProtocol.encode(:ping, node_id: state[:own_node_id])
    :gen_udp.send(state[:socket], state[:ip], state[:port], payload)

    {:noreply, state}
  end

  def handle_call({:find_node, target}, _from, state) do
    Logger.debug("[#{Hexate.encode(state[:node_id])}] << find_node")

    payload = KRPCProtocol.encode(:find_node, node_id: state.node_id, target: target)
    :gen_udp.send(state.socket, state[:ip], state[:port], payload)

    {:reply, :ok, state}
  end

  def handle_call(:send_ping_reply, _from, state) do
    Logger.debug("[#{Hexate.encode(state[:node_id])}] << ping_reply")

    payload =  KRPCProtocol.encode(:ping_reply, node_id: state.node_id)
    :gen_udp.send(state.socket, state[:ip], state[:port], payload)

    {:reply, :ok, state}
  end

  def handle_call(:update_last_received, _from, state) do
    {:reply, :ok, %{state | :last_received => :os.system_time(:seconds)}}
  end



end
