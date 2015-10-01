defmodule RoutingTable.Bucket do
  use GenServer

  require Logger

  ## BEP 05 sets k to 8
  @k_buckets 8

  def start_link do
    {:ok, server} = GenServer.start_link(__MODULE__, [])
    server
  end


  def size(server) do
    GenServer.call(server, :size)
  end

  def put(server, node_id, pid) do
    GenServer.call(server, {:put, node_id, pid})
  end

  def delete(server, node_id) do
    GenServer.call(server, {:delete, node_id})
  end

  def is_full?(server) do
    GenServer.call(server, :is_full)
  end

  def has_space?(server) do
    GenServer.call(server, :has_space)
  end

  def has_node?(server, node_id) do
    GenServer.call(server, {:has_node, node_id})
  end

  def nodes(server) do
    GenServer.call(server, :nodes)
  end

  def get(server, node_id) do
    GenServer.call(server, {:get, node_id})
  end

  ###
  ## GenServer API
  ###

  def init([]) do
    {:ok, [nodes: %{}]}
  end

  def handle_call(:size, _from, state) do
    {:reply, Dict.size(state[:nodes]), state}
  end

  def handle_call({:put, node_id, pid}, _from, state) do
    {:reply, {:ok}, [nodes: Dict.put(state[:nodes], node_id, pid)]}
  end

  def handle_call({:delete, node_id}, _from, state) do
    {:reply, {:ok}, [nodes: Dict.delete(state[:nodes], node_id)]}
  end

  def handle_call({:get, node_id}, _from, state) do
    {:reply, Dict.get(state[:nodes], node_id), state}
  end

  def handle_call(:is_full, _from, state) do
    {:reply, Dict.size(state[:nodes]) == @k_buckets , state}
  end

  def handle_call(:has_space, _from, state) do
    {:reply, Dict.size(state[:nodes]) < @k_buckets , state}
  end

  def handle_call({:has_node, node_id}, _from, state) do
    {:reply, Dict.has_key?(state[:nodes], node_id), state}
  end

  def handle_call(:nodes, _from, state) do
    {:reply, Dict.keys(state[:nodes]), state}
  end
end
