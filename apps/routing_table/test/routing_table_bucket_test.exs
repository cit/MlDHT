defmodule RoutingTable.Bucket.Test do
  use ExUnit.Case, async: true

  alias RoutingTable.Bucket

  ## Initialize a bucket
  setup do
    bucket = Bucket.start_link
    {:ok, bucket: bucket}
  end

  test "size function", %{bucket: bucket} do
    assert Bucket.size(bucket) == 0

    assert {:ok} == Bucket.put(bucket, "AA", 42)
    assert Bucket.size(bucket) == 1

    assert {:ok} == Bucket.put(bucket, "BB", 42)
    assert Bucket.size(bucket) == 2

    assert {:ok} == Bucket.delete(bucket, "AA")
    assert Bucket.size(bucket) == 1

    assert {:ok} == Bucket.delete(bucket, "BB")
    assert Bucket.size(bucket) == 0
  end

  test "full? function", %{bucket: bucket} do
    Enum.map(1..8, fn(x) -> Bucket.put(bucket, to_string(x), x) end)
    assert Bucket.size(bucket) == 8
    assert Bucket.is_full?(bucket) == true

    assert {:ok} == Bucket.delete(bucket, "8")
    assert Bucket.is_full?(bucket) == false

    Enum.map(1..7, fn(x) -> Bucket.delete(bucket, to_string(x)) end)
  end

  test "has_space? function", %{bucket: bucket} do
    Enum.map(1..8, fn(x) -> Bucket.put(bucket, to_string(x), x) end)
    assert Bucket.size(bucket) == 8
    assert Bucket.has_space?(bucket) == false

    assert {:ok} == Bucket.delete(bucket, "8")
    assert Bucket.has_space?(bucket) == true

    Enum.map(1..7, fn(x) -> Bucket.delete(bucket, to_string(x)) end)
  end


  test "has_node? function", %{bucket: bucket} do
    assert {:ok} == Bucket.put(bucket, "AA", 42)
    assert Bucket.has_node?(bucket, "AA") == true
    assert Bucket.has_node?(bucket, "BB") == false
  end

  test "nodes function", %{bucket: bucket} do
    assert {:ok} == Bucket.put(bucket, "AA", 42)
    assert {:ok} == Bucket.put(bucket, "BB", 23)
    assert {:ok} == Bucket.put(bucket, "CC", 5)

    assert Bucket.nodes(bucket) == ["AA", "BB", "CC"]
  end

end
