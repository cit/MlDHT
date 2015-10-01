defmodule RoutingTable.Worker.Test do
  use ExUnit.Case
  require Logger

  alias RoutingTable.Worker, as: RoutingTable

  setup do
    RoutingTable.node_id("AA")
  end

  test "If the function node_id can set and get the node_id" do
    RoutingTable.node_id("BB")
    assert RoutingTable.node_id == "BB"
  end

  test "If the size of the table is 0 if we add and delete a node" do
    assert true == RoutingTable.add_node("BB", {{127, 0, 0, 1}, 6881}, 23) |> Process.alive?
    RoutingTable.delete("BB")

    assert RoutingTable.size == 0
  end

  test "Add 8 nodes" do
    nodes = ["AB", "7A", "EF", "FE", "20", "4D", "2C", "7D"]
    Enum.map(nodes, fn(x) ->
      assert true == RoutingTable.add_node(x, {{127, 0, 0, 1}, 6881}, x) |> Process.alive?
    end)
    assert RoutingTable.size == 8

    Enum.map(nodes, fn(x) -> RoutingTable.delete(x) end)
    assert RoutingTable.size == 0
  end

  test "get_node" do
    # assert :ok == RoutingTable.add_node("BB", {{127, 0, 0, 1}, 6881}, 23)

    # pid = RoutingTable.get_node("BB")
    # assert Kernel.is_pid(pid) == true
    # assert RoutingTable.get_node("CC") == nil

    # RoutingTable.delete("BB")
  end

  test "If the function find_bucket works correctly" do
    assert RoutingTable.find_bucket("abc", "bca") == 6
    assert RoutingTable.find_bucket("bca", "abc") == 6

    assert RoutingTable.find_bucket("AA", "aa") == 2
    assert RoutingTable.find_bucket("aa", "AA") == 2

    assert RoutingTable.find_bucket(<<0b00000010>>, <<0b00000010>>) == 8
    assert RoutingTable.find_bucket(<<0b10000010>>, <<0b00000010>>) == 0
    assert RoutingTable.find_bucket(<<0b11110000>>, <<0b11111111>>) == 4
  end

  test "foo" do
    nodes = [
      "32f54e697351ff4aec29cdbaabf2fbe3467cc267",
      "93990a2be65c366458ef03acb48680ae83d2ad94",
      "9399182c807ec599d5e980b2eac9cc53bf67d69d",
      "93991b09293ce71a85b44d0578d576b9d09cc095",
      "91478cdbd190e87d21c273f493957590a78d2b50",
      "93991f40b451be18d727bfcae0ea1722fd65732a",
      "9077c97800e42b0757e4f39ff8dd9e3e8ab67675",
      "96cb5cea7c9fb775c1fb74de0121d7a11309ecc7",
      "527429ee61360b9d6a69bcce493fb12250be7ece",
      "a14e7753748539120787bce2b9815cc80af3174c",
      "003e8f4139a0174fb0f1983b87d76dfacd29b783",
    ]

    ## set a real node id
    Hexate.decode("fc8a15a2faf2734dbb1dc5f7afdc5c9beaeb1f59")
    |> RoutingTable.node_id

    ## add all nodes
    Enum.map(nodes, fn(x) ->
      RoutingTable.add_node(Hexate.decode(x), {{127, 0, 0, 1}, 6881}, 23)
    end)

    RoutingTable.add_node(<<147,153,6,71,222,179,18,77,200,67,187,139,166,31,3,90,125,9,56,6>>, {{127, 0, 0, 1}, 6881}, nil)
    RoutingTable.print
    Enum.map(nodes, fn(x) -> RoutingTable.delete(Hexate.decode(x)) end)
    RoutingTable.print

    RoutingTable.node_id("AA")
  end

  # test "foo" do
  #   node = "9c499d098702f151d210fc79baa4ac167c1df78e"
  #   nodes = [
  #     "44e525ac31835b1de9803d2ed1b50fa3ed307819",
  #     "50688393106b11f2ce01a34ef482c4755685a5c6",
  #     "32f54e697351ff4aec29cdbaabf2fbe3467cc267",
  #     "2c76a5209eb78316798079ce0e794bdd29e8d97a",
  #     "08cf801483565911b86fde0ef92e30c706641fa7",b
  #     "6d75e285902e2e537129dbcab26ade07edba714a",
  #     "7eb937a06be9026ac3f8cc6510999069580d976a",
  #     "7e1aa34d6c831ff5f18f3b7a3cc96af9bc2b69b7",
  #   ]

  #   Enum.map(nodes, fn(x) ->
  #     foo = RoutingTable.find_bucket(node, x)
  #     Logger.debug(foo)
  #   end)
  # end

  #   test "foo 2" do
  #   node = "9c499d098702f151d210fc79baa4ac167c1df78e"
  #   nodes = [

  #   ]

  #   Enum.map(nodes, fn(x) ->
  #     foo = RoutingTable.find_bucket(node, x)
  #     Logger.debug(foo)
  #   end)

  # end
end
