defmodule RoutingTable.Worker do
  use GenServer

  require Logger
  require Bitwise

  alias RoutingTable.Node
  alias RoutingTable.Timer

  #############
  # Constants #
  #############

  ## Module name
  @name __MODULE__

  ## 5 Minutes
  @review_time 60 * 5

  ## 15 minutes
  @response_time 60 * 15

  ##############
  # Public API #
  ##############

  def start_link do
    GenServer.start_link(__MODULE__, ["AAAAAAAAAAAAAAAAAAAA"], name: @name)
  end

  def add(remote_node_id, address, socket) do
    GenServer.call(@name, {:add, remote_node_id, address, socket})
  end

  def del(node_id) do
    GenServer.call(@name, {:del, node_id})
  end

  def node_id(node_id) do
    GenServer.call(@name, {:node_id, node_id})
  end

  def node_id do
    GenServer.call(@name, :node_id)
  end

  def size do
    GenServer.call(@name, :size)
  end

  def print do
    GenServer.cast(@name, :print)
  end

  def get(node_id) do
    GenServer.call(@name, {:get, node_id})
  end

  def get(node_id, address, socket) do
    GenServer.call(@name, {:get, node_id, address, socket})
  end

  def closest_nodes(target) do
    GenServer.call(@name, {:closest_nodes, target})
  end


  def exists?(node_id) do
    GenServer.call(@name, {:exists?, node_id})
  end


  #################
  # GenServer API #
  #################

  def init([node_id]) do
    ## Start review timer
    Timer.start_link(self, :review, @review_time * 1000)

    {:ok, [node_id: node_id, buckets: [[]] ]}
  end

  def handle_info(:review, state) do
    new_buckets = Enum.map(state[:buckets], fn(bucket) ->
      Enum.filter(bucket, fn(pid) ->
        time = Node.last_time_responded(pid)
        cond do
          time < @response_time ->
            Node.send_ping(pid)

          time >= @response_time and Node.is_good?(pid) ->
            Node.goodness(pid, :questionable)
            Node.send_ping(pid)

          time >= @response_time and Node.is_questionable?(pid) ->
            Logger.debug "[#{Hexate.encode Node.id(pid)}] Deleted"
            Node.stop(pid)
            false
        end

      end)
    end)

    ## Restart the Timer
    Timer.start_link(self, :review, @review_time * 1000)

    {:noreply, [node_id: state[:node_id], buckets: new_buckets]}
  end

  def handle_call({:closest_nodes, target}, _from, state ) do
    list = List.flatten(state[:buckets])
    |> Enum.sort(fn(x, y) -> xor_compare(Node.id(x), Node.id(y), target, &(&1 < &2)) end)
    |> Enum.slice(0..7)

    {:reply, list, state}
  end

  @doc """
  TODO
  """
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


  def distance(node_id_a, node_id_b), do: distance(node_id_a, node_id_b, [])

  def distance("", "", result), do: List.to_string(result)

  def distance(node_id_a, node_id_b, result) do
    << byte_a :: 8, rest_a :: bitstring >> = node_id_a
    << byte_b :: 8, rest_b :: bitstring >> = node_id_b

    distance(rest_a, rest_b, result ++ [Bitwise.bxor(byte_a, byte_b)])
  end

  def handle_call({:exists?, node_id}, _from, state) do
    {:reply, node_exists?(state[:buckets], node_id), state}
  end

  def handle_call({:get, node_id}, _from, state) do
    {:reply, get_node(state[:buckets], node_id), state}
  end

  def handle_call({:get, node_id, address, socket}, _from, state) do
    node_tuple = {node_id, address, socket}

    case get_node(state[:buckets], node_id) do
      node_pid when node_pid != nil ->
        {:reply, node_pid, state}
      _ ->
        new_buckets = add_node(state[:node_id], state[:buckets], node_tuple)
        node_pid = get_node(new_buckets, node_id)

        {:reply, node_pid, [node_id: state[:node_id], buckets: new_buckets]}
    end
  end


  def handle_call(:size, _from, state) do
    size = Enum.map( state[:buckets], fn(b)-> Enum.count(b) end)
    |> Enum.reduce(fn(x, acc) -> x + acc end)

    {:reply, size, state}
  end

  def handle_call({:del, node_id}, _from, state) do
    {:reply, :ok, [node_id: state[:node_id],
                   buckets: del_node(state[:buckets], node_id)]}
  end

  def handle_cast(:print, state) do
    state[:buckets]
    |> Stream.with_index
    |> Enum.each(fn ({bucket, index}) ->
      size = Enum.count(bucket)
      Logger.debug "### Bucket #{index} ### (#{size})"

      Enum.each(bucket, fn(pid) ->
        Logger.debug "#{Hexate.encode(Node.id(pid))} #{inspect Node.goodness(pid)}"
      end)
    end)

    {:noreply, state}
  end

  def handle_call(:node_id, _from, state) do
    {:reply, state[:node_id], state}
  end

  def handle_call({:node_id, node_id}, _from, state) do
    {:reply, :ok, [node_id: node_id, buckets: state[:buckets]]}
  end

  def handle_call({:add, node_id, address, socket}, _from, state) do
    unless node_exists?(state[:buckets], node_id) do
      node_tuple = {node_id, address, socket}

      {:reply, :ok, [node_id: state[:node_id],
                     buckets: add_node(state[:node_id], state[:buckets], node_tuple)]}
    else
      {:reply, :ok, state}
    end
  end

  ###
  ## Private Functions
  ###

  @doc """
  TODO
  """
  def add_node(my_node_id, buckets, node) do
    index  = find_bucket_index(buckets, my_node_id, elem(node, 0))
    bucket = Enum.at(buckets, index)

    cond do
      ## If the bucket has still some space left, we can just add the node to
      ## the bucket. Easy Peasy
      Enum.count(bucket) < 8 ->
        List.replace_at(buckets, index, bucket ++ [Node.start_link(my_node_id, node)])

        ## If the bucket is full and the node would belong to a bucket that is far
        ## away from us, we will just drop that node. Go away you filthy node!
        Enum.count(bucket) == 8 and index != index_last_bucket(buckets) ->
        Logger.error "Bucket #{index} is full -> drop #{Hexate.encode(elem(node, 0))}"
      buckets

      ## If the bucket is full but the node is closer to us, we will reorganize
      ## the nodes in the buckets and try again to add it to our bucket list.
      true ->
          buckets = reorganize(bucket, buckets ++ [[]], my_node_id)
          add_node(my_node_id, buckets, node)
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

  @doc """
  TODO
  """
  def reorganize([], buckets, _self_node_id), do: buckets
  def reorganize([node | rest], buckets, my_node_id) do
    current_index  = length(buckets) - 2
    index          = find_bucket_index(buckets, my_node_id, Node.id(node))

    if (current_index != index) do
      current_bucket = Enum.at(buckets, current_index)
      new_bucket     = Enum.at(buckets, index)

      ## Remove the node from the current bucket
      filtered_bucket = Enum.filter(current_bucket, fn(x) ->
        Node.id(node) != Node.id(x)
      end)

      ## Then add it to the new_bucket
      buckets = List.replace_at(buckets, current_index, filtered_bucket)
      |> List.replace_at(index, new_bucket ++ [node])
    end

    reorganize(rest, buckets, my_node_id)
  end

  @doc """
  Returns the index of the last bucket as integer.

  """
  def index_last_bucket(buckets) do
    Enum.count(buckets) -1
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

    min(bucket_index, index_last_bucket(buckets))
  end

  @doc """
  TODO
  """
  def node_exists?(buckets, node_id) do
    Enum.any?(buckets, fn(bucket) ->
      Enum.any?(bucket, fn(node) ->
        node_id == Node.id(node)
      end)
    end)
  end

  @doc """
  TODO
  """
  def del_node(buckets, node_id) do
    Enum.map(buckets, fn(bucket) ->
      Enum.filter(bucket, fn(x) -> node_id != Node.id(x) end)
    end)
  end

  @doc """

  """
  def get_node(buckets, node_id) do
    Enum.map(buckets, fn(bucket) ->
      Enum.find(bucket, fn(pid) ->
        Node.id(pid) == node_id
      end)
    end) |> Enum.find(fn(x) -> Kernel.is_pid(x) end)
  end

end
