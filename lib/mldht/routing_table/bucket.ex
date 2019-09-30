defmodule MlDHT.RoutingTable.Bucket do
  @moduledoc false

  alias MlDHT.RoutingTable.Bucket
  alias MlDHT.RoutingTable.Node

  require Logger

  defstruct index: 0, last_update: 0, nodes: []

  @k_bucket 8

  def new(index) do
    %Bucket{index: index, last_update: :os.system_time(:seconds)}
  end

  def size(bucket) do
    Enum.count(bucket.nodes)
  end

  def age(bucket) do
    :os.system_time(:seconds) - bucket.last_update
  end

  def is_full?(bucket) do
    Enum.count(bucket.nodes) == @k_bucket
  end

  def has_space?(bucket) do
    Enum.count(bucket.nodes) < @k_bucket
  end

  def add(bucket, element) when is_list(element) do
    %{ Bucket.new(bucket.index) |nodes: bucket.nodes ++ List.flatten(element)}
  end

  def update(bucket) do
    %{ Bucket.new(bucket.index) |nodes: bucket.nodes }
  end

  def add(bucket, element) do
    %{ Bucket.new(bucket.index) |nodes: bucket.nodes ++ [element]}
  end

  def filter(bucket, func) do
    %{bucket | nodes: Enum.filter(bucket.nodes, func)}
  end

  def get(bucket, node_id) do
    Enum.find(bucket.nodes, fn(node_pid) -> Node.id(node_pid) == node_id end)
  end

  def del(bucket, node_id) do
    nodes = Enum.filter(bucket.nodes, fn(pid) -> Node.id(pid) != node_id end)
    %{bucket | nodes: nodes}
  end


  defimpl Inspect, for: Bucket do
    def inspect(bucket, _) do
      size  = Bucket.size(bucket)
      age   = Bucket.age(bucket)

      if size == 0 do
        "#Bucket<index: #{bucket.index}, size: #{size}, age: #{age}>"
      else
        nodes = Enum.map(bucket.nodes, fn(x) ->
          "  " <> Node.to_string(x) <> "\n"
        end)
        """
        #Bucket<index #{bucket.index}, size: #{size}, age: #{age}
        #{nodes}>
        """
      end
    end
  end


end
