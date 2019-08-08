defmodule MlDHT.Server.Storage.Test do
  use ExUnit.Case
  require Logger

  alias MlDHT.Server.Storage

  test "has_nodes_for_infohash?" do
    Storage.put("aaaa", {127, 0, 0, 1}, 6881)

    assert Storage.has_nodes_for_infohash?("bbbb") == false
    assert Storage.has_nodes_for_infohash?("aaaa") == true
  end

  test "get_nodes" do
    Storage.put("aaaa", {127, 0, 0, 1}, 6881)
    Storage.put("aaaa", {127, 0, 0, 1}, 6881)
    Storage.put("aaaa", {127, 0, 0, 2}, 6882)

    Storage.print

    assert Storage.get_nodes("aaaa") == [{{127,0,0,1}, 6881}, {{127, 0, 0, 2}, 6882}]
  end

end
