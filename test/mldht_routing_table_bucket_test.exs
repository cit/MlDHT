defmodule MlDHT.RoutingTable.Bucket.Test do
  use ExUnit.Case

  require Logger

  alias MlDHT.RoutingTable.Bucket

  test "size function" do
    bucket = Bucket.new(0)
    assert Bucket.size(bucket) == 0

    bucket =
      Bucket.add(bucket, "elem1")
    |> Bucket.add("elem2")
    |> Bucket.add("elem3")

    assert Bucket.size(bucket) == 3
  end

  test "if is_full?/1 returns false when only 6 elements are added" do
    list_half_full = [1, 2, 3, 4, 5, 6]
    assert Bucket.new(0) |> Bucket.add(list_half_full) |> Bucket.is_full? == false
  end

  test "if is_full?/1 returns true when only 8 elements are added" do
      list_full = [1, 2, 3, 4, 5, 6, 7, 8]
      assert Bucket.new(0) |> Bucket.add(list_full) |> Bucket.is_full? == true
  end

  test "if has_space?/1 returns true when only 6 elements are added" do
    list_half_full = [1, 2, 3, 4, 5, 6]
    assert Bucket.new(0) |> Bucket.add(list_half_full) |> Bucket.has_space? == true
  end

  test "if has_space?/1 returns false when only 8 elements are added" do
    list_full = [1, 2, 3, 4, 5, 6, 7, 8]
    assert Bucket.new(0) |> Bucket.add(list_full) |> Bucket.has_space? == false
  end

  test "if different value for k_bucket_size" do
    default_k = Application.get_env(:mldht, :k_bucket_size)
    new_k     = 20

    # Set a new value of k
    Application.put_env(:mldht, :k_bucket_size, new_k)

    # Test if the bucket has space if we add as much nodes as the new bucket size
    list_full = 1..new_k |> Enum.to_list()
    assert Bucket.new(0) |> Bucket.add(list_full) |> Bucket.has_space? == false

    # Set previous default value of k for the other tests
    Application.put_env(:mldht, :k_bucket_size, default_k)
  end

  test "if age/1 works correctly with waiting one second" do
    bucket = Bucket.new(0)
    :timer.sleep(1000)

    assert Bucket.age(bucket) >= 1
  end

  test "if age/1 works correctly without waiting" do
    bucket = Bucket.new(0)
    assert Bucket.age(bucket) < 1
  end

  test "if age/1 works correctly when adding a new node" do
    bucket = Bucket.new(0)
    :timer.sleep(1000)
    new_bucket = Bucket.add(bucket, "elem")
    assert Bucket.age(new_bucket) < 1
  end

  test "if update/1 creates a new Bucket" do
    bucket = Bucket.new(0)
    :timer.sleep(1000)
    new_bucket = Bucket.update(bucket)
    assert Bucket.age(new_bucket) < 1
  end

  test "if update/1 still has the same nodes" do
    bucket     = Bucket.new(0) |> Bucket.add([1, 2, 3, 4, 5])
    new_bucket = Bucket.update(bucket)
    assert Bucket.size(new_bucket) == 5
  end

end
