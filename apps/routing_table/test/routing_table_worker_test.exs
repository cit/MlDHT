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
    RoutingTable.add("BB", {{127, 0, 0, 1}, 6881}, 23)
    assert RoutingTable.size == 1

    RoutingTable.del("BB")
    assert RoutingTable.size == 0
  end

  test "get_node" do
    assert :ok == RoutingTable.add("BB", {{127, 0, 0, 1}, 6881}, 23)

    assert RoutingTable.get("BB") |> Kernel.is_pid == true
    assert RoutingTable.get("CC") == nil

    RoutingTable.del("BB")
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
      "93990647deb3124dc843bb8ba61f035a7d093806",
    ]

    ## set a real node id
    Hexate.decode("fc8a15a2faf2734dbb1dc5f7afdc5c9beaeb1f59")
    |> RoutingTable.node_id

    ## add all nodes
    Enum.map(nodes, fn(x) ->
      RoutingTable.add(Hexate.decode(x), {{127, 0, 0, 1}, 6881}, 23)
    end)

    RoutingTable.print()
    RoutingTable.closest_nodes(Hexate.decode "dac8fac14c12bb46e25f15d810bbd14267ad4eca")

    Enum.map(nodes, fn(x) -> RoutingTable.del(Hexate.decode(x)) end)
    # RoutingTable.print

    RoutingTable.node_id("AA")
  end

  test "Double entries" do
    RoutingTable.add("BB", {{127, 0, 0, 1}, 6881}, 23)
    RoutingTable.add("BB", {{127, 0, 0, 1}, 6881}, 23)

    assert RoutingTable.size == 1
    RoutingTable.del("BB")
  end







end
