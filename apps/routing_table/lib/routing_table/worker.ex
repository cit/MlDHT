defmodule RoutingTable.Worker do
  use GenServer

  require Logger

  alias RoutingTable.Bucket
  alias RoutingTable.Node

  @name __MODULE__

  ##############
  # Public API #
  ##############

  def start_link do
    GenServer.start_link(__MODULE__, ["AAAAAAAAAAAAAAAAAAAA"], name: @name)
  end

  def node_id do
    GenServer.call(@name, :node_id)
  end

  def node_id(node_id) do
    GenServer.call(@name, {:node_id, node_id})
  end

  def add_node(remote_node_id, address, socket) do
    GenServer.call(@name, {:add_node, remote_node_id, address, socket})
  end

  def delete(node_id) do
    GenServer.call(@name, {:delete, node_id})
  end

  def size do
    GenServer.call(@name, :size)
  end

  def print do
    GenServer.call(@name, :print)
  end

  def get_node(node_id, address, socket) do
    GenServer.call(@name, {:get_node, node_id, address, socket})
  end


  #################
  # GenServer API #
  #################

  def init([node_id]) do
    {:ok, [node_id: node_id, buckets: [Bucket.start_link]]}
  end

  def handle_call(:node_id, _from, state) do
    {:reply, state[:node_id], state}
  end

  def handle_call({:node_id, node_id}, _from, state) do
    {:reply, :ok, [node_id: node_id, buckets: state[:buckets]]}
  end

  def handle_call(:size, _from, state) do
    size = Enum.map(state[:buckets], fn(b) -> Bucket.size(b) end)
    |> Enum.sum
    {:reply, size, state}
  end

  def handle_call(:print, _from, state) do
    state[:buckets]
    |> Stream.with_index
    |> Enum.each(fn ({bucket, index}) ->
      size = Bucket.size(bucket)
      Logger.debug "### Bucket #{index} ### (#{size})"

      Bucket.nodes(bucket)
      |> Enum.each(fn(node) ->
        Logger.debug "Node #{Hexate.encode(node)}"
      end)
    end)

    {:reply, :ok, state}
  end

  def handle_call({:get_node, node_id, address, socket}, _from, state) do
    node_pid = get_node(node_id, state)

    if Kernel.is_pid(node_pid) and Process.alive?(node_pid) do
      {:reply, node_pid, state}
    else
      {node_pid, new_state} = add(node_id, address, socket, state)
      {:reply, node_pid, new_state}
    end
  end

  def handle_call({:add_node, node_id, address, socket}, _from, state) do
    {node_pid, new_state} = add(node_id, address, socket, state)
    {:reply, node_pid, new_state}
  end

  def handle_call({:delete, node_id}, _from, state) do
    pid = Enum.find(state[:buckets], nil, fn (bucket) ->
      Bucket.has_node?(bucket, node_id)
    end)

    node_pid = Bucket.get(pid, node_id)
    Bucket.delete(pid, node_id)
    Node.stop(node_pid)

    {:reply, :ok, state}
  end


  ###
  ## Private Functions
  ###

  @doc """
  This function searchs for a node in all buckets and if it makes a find it
  returns the pid of the bucket process. If not, nil will be returned.
  """
  def get_bucket(node_id, state) do
    Enum.find(state[:buckets], nil, fn (bucket) ->
      Bucket.has_node?(bucket, node_id)
    end)
  end

  @doc """
  This function returns the pid of node if it exists in a bucket. If not it will
  return nil.
  """
  def get_node(node_id, state) do
    bucket_pid = get_bucket(node_id, state)

    if bucket_pid != nil and Process.alive?(bucket_pid) do
      Bucket.get(bucket_pid,node_id)
    end
  end

  @doc """
  This function takes two node ids as binary and returns the bucket
  number in which the node_id belongs as an integer. It counts the
  number of identical bits.

  ## Example
    iex> RoutingTable.find_bucket(<<0b11110000>>, <<0b11111111>>)
    4
  """
  def find_bucket(node_id_a, node_id_b), do: find_bucket(node_id_a, node_id_b, 0)
  def find_bucket("", "", bucket), do: bucket
  def find_bucket(node_id_a, node_id_b, bucket) do
    << bit_a :: 1, rest_a :: bitstring >> = node_id_a
    << bit_b :: 1, rest_b :: bitstring >> = node_id_b

    if bit_a == bit_b do
      find_bucket(rest_a, rest_b, (bucket + 1))
    else
      bucket
    end
  end

  def reorganize([], buckets, _self_node_id), do: buckets
  def reorganize([node_id | rest], buckets, self_node_id) do
    current_index  = length(buckets) - 2
    index          = find_bucket_index(buckets, self_node_id, node_id)
    current_bucket = Enum.at(buckets, current_index)

    Logger.debug "#{Hexate.encode node_id} move from #{current_index} to #{index}"

    if (current_index != index) do
      ## remove value
      node_pid = Bucket.get(current_bucket, node_id)
      {:ok} = Bucket.delete(current_bucket, node_id)

      ## add node to the new bucket
      Bucket.put(Enum.at(buckets, index), node_id, node_pid)
    end

    reorganize(rest, buckets, self_node_id)
  end

  defp add(node_id, address, socket, state) do
    index  = find_bucket_index(state[:buckets], state[:node_id], node_id)
    bucket = Enum.at(state[:buckets], index)

    cond do
      ## If the bucket has still some space left, we can just add the node to
      ## the bucket. Easy Peasy
      Bucket.has_space?(bucket) ->
        node_pid = RoutingTable.Node.start_link(state[:node_id], {node_id, address, socket})
        {:ok} = Bucket.put(bucket, node_id, node_pid)
        {node_pid, state}
      ## If the bucket is full and the node would belong to a bucket that is far
      ## away from us, we will just drop that node. Go away you filthy node!
      Bucket.is_full?(bucket) and index != index_last_bucket(state[:buckets]) ->
        Logger.error "Bucket #{index} is full -> drop #{Hexate.encode(node_id)}"
        {nil, state}
      ## If the bucket is full but the node is closer to us, we will reorganize
      ## the nodes in the buckets and try again to add it to our bucket list.
      true ->
          buckets = state[:buckets] ++ [Bucket.start_link()]
          Enum.at(state[:buckets], index_last_bucket(state[:buckets]))
          |> Bucket.nodes
          |> reorganize(buckets, state[:node_id])

          ## There might the rare case that all nodes are still in the same
          ## bucket even when we reorganized the bucket. In that case we also
          ## need to drop the node.
          if (Bucket.has_space?(bucket)) do
            add(node_id, address, socket, state)
          else
            Logger.error "Bucket #{index} is full -> drop #{Hexate.encode(node_id)} rare case drop"
          end

          {nil, [node_id: state[:node_id], buckets: buckets]}
    end
  end

  ## Returns the index of the last bucket as integer.
  def index_last_bucket(buckets) do
    len = length(buckets) - 1
    if len < 0 do 0 else len end
  end

  @doc """
  TODO

  """
  def find_bucket_index(buckets, self_node_id, remote_node_id) do
    unless byte_size(self_node_id) == byte_size(remote_node_id) do
      Logger.error "self_node_id: #{String.length(self_node_id)}
      remote_node_id: #{String.length(remote_node_id)}"
      raise ArgumentError, message: "Different length of self_node_id and remote_node_id"
    end
    bucket_index = find_bucket(self_node_id, remote_node_id)

    # Logger.debug "ind: #{bucket_index} len: #{index_last_bucket(buckets)}"
    min(bucket_index, index_last_bucket(buckets))
  end

end
