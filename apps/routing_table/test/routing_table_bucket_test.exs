defmodule RoutingTable.Bucket.Test do
  use ExUnit.Case

  require Logger

  alias RoutingTable.Bucket
  alias RoutingTable.Node

  test "size function" do
    bucket = Bucket.new
    assert Bucket.size(bucket) == 0

    bucket =
      Bucket.add(bucket, "elem1")
    |> Bucket.add("elem2")
    |> Bucket.add("elem3")

    assert Bucket.size(bucket) == 3
  end

  test "is_full?/1 function" do
    assert Bucket.new |> Bucket.add([1,2,3,4,5,6])     |> Bucket.is_full? == false
    assert Bucket.new |> Bucket.add([1,2,3,4,5,6,7,8]) |> Bucket.is_full? == true
  end

  test "has_space?/1 function" do
    assert Bucket.new |> Bucket.add([1,2,3,4,5,6])     |> Bucket.has_space? == true
    assert Bucket.new |> Bucket.add([1,2,3,4,5,6,7,8]) |> Bucket.has_space? == false
  end

  test "foo" do
    bucket = Bucket.new
    bucket = Bucket.add(bucket, Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil}))
    bucket = Bucket.add(bucket, Node.start_link("AA", {"CC", {{127, 0, 0, 1}, 6881}, nil}))

    Logger.debug "\n#{inspect bucket}"
  end


end
