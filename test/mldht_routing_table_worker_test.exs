defmodule MlDHT.RoutingTable.Worker.Test do
  use ExUnit.Case

  @name :test

  setup do
    rt_name = "test_rt"
    node_id =  "AAAAAAAAAAAAAAAAAAAB"
    node_id_enc = Base.encode16(node_id)

    start_supervised!({
      DynamicSupervisor,
      name: MlDHT.Registry.via(node_id_enc, MlDHT.RoutingTable.NodeSupervisor, rt_name),
      strategy: :one_for_one})

    start_supervised!({
      MlDHT.RoutingTable.Worker,
      name:    @name,
      node_id: node_id,
      rt_name: rt_name})

    [node_id: node_id, node_id_enc: node_id_enc, rt_name: rt_name]
  end

  test "If the size of the table is 0 if we add and delete a node" do
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)
    assert MlDHT.RoutingTable.Worker.size(@name) == 1

    MlDHT.RoutingTable.Worker.del(@name, "BBBBBBBBBBBBBBBBBBBB")
    assert MlDHT.RoutingTable.Worker.size(@name) == 0
  end

  test "get_node" do
    assert :ok == MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)

    assert MlDHT.RoutingTable.Worker.get(@name, "BBBBBBBBBBBBBBBBBBBB") |> Kernel.is_pid == true
    assert MlDHT.RoutingTable.Worker.get(@name, "CCCCCCCCCCCCCCCCCCCC") == nil

    MlDHT.RoutingTable.Worker.del(@name, "BBBBBBBBBBBBBBBBBBBB")
  end

  test "Double entries" do
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)

    assert MlDHT.RoutingTable.Worker.size(@name) == 1
    MlDHT.RoutingTable.Worker.del(@name, "BBBBBBBBBBBBBBBBBBBB")
  end

  test "if del() really deletes the node from the routing table" do
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)
    node_pid = MlDHT.RoutingTable.Worker.get(@name, "BBBBBBBBBBBBBBBBBBBB")

    assert Process.alive?(node_pid) == true
    MlDHT.RoutingTable.Worker.del(@name, "BBBBBBBBBBBBBBBBBBBB")
    assert Process.alive?(node_pid) == false
  end

  test "if routing table size and cache size are equal with two elements" do
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "CCCCCCCCCCCCCCCCCCCC", {{127, 0, 0, 1}, 6881}, 23)

    assert MlDHT.RoutingTable.Worker.size(@name) == MlDHT.RoutingTable.Worker.cache_size(@name)
  end

  test "if routing table size and cache size are equal with ten elements" do
    Enum.map(?B .. ?Z, fn(x) -> String.duplicate(<<x>>, 20) end)
    |> Enum.each(fn(node_id) ->
      MlDHT.RoutingTable.Worker.add(@name, node_id, {{127, 0, 0, 1}, 6881}, 23)
    end)

    MlDHT.RoutingTable.Worker.del(@name, "BBBBBBBBBBBBBBBBBBBB")
    MlDHT.RoutingTable.Worker.del(@name, "CCCCCCCCCCCCCCCCCCCC")
    MlDHT.RoutingTable.Worker.del(@name, "DDDDDDDDDDDDDDDDDDDD")

    assert MlDHT.RoutingTable.Worker.size(@name) == MlDHT.RoutingTable.Worker.cache_size(@name)
  end

  test "if closest_node() return only the closest nodes", test_worker_context do
    node_id = test_worker_context.node_id

    ## Generate close node_ids
    close_nodes = 1 .. 16
    |> Enum.map(fn(x) -> MlDHT.RoutingTable.Distance.gen_node_id(160 - x, node_id) end)
    |> Enum.filter(fn(x) -> x != node_id end)
    |> Enum.uniq()
    |> Enum.slice(0 .. 7)
    |> Enum.sort()

    ## Add the close nodes to the RoutingTable
    Enum.each(close_nodes, fn(node) ->
      MlDHT.RoutingTable.Worker.add(@name, node, {{127, 0, 0, 1}, 6881}, nil)
    end)

    assert MlDHT.RoutingTable.Worker.size(@name) == 8

    ## Generate and add distant nodes
    Enum.map(?B .. ?I, fn(x) -> String.duplicate(<<x>>, 20) end)
    |> Enum.each(fn(node_id) ->
      MlDHT.RoutingTable.Worker.add(@name, node_id, {{127, 0, 0, 1}, 6881}, 23)
    end)

    assert MlDHT.RoutingTable.Worker.size(@name) == 16

    list = MlDHT.RoutingTable.Worker.closest_nodes(@name, node_id)
    |> Enum.map(fn(x) -> MlDHT.RoutingTable.Node.id(x)  end)
    |> Enum.sort()

    ## list and close_nodes must be equal
    assert list == close_nodes
  end

  test "if routing table closest_nodes filters the source" do
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "CCCCCCCCCCCCCCCCCCCC", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "DDDDDDDDDDDDDDDDDDDD", {{127, 0, 0, 1}, 6881}, 23)

    node_id = "AAAAAAAAAAAAAAAAAAAB"
    source  = "CCCCCCCCCCCCCCCCCCCC"

    list = MlDHT.RoutingTable.Worker.closest_nodes(@name, node_id, source)
    assert length(list) == 2
  end

  test "if routing table closest_nodes does not filters the source" do
    MlDHT.RoutingTable.Worker.add(@name, "BBBBBBBBBBBBBBBBBBBB", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "CCCCCCCCCCCCCCCCCCCC", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "DDDDDDDDDDDDDDDDDDDD", {{127, 0, 0, 1}, 6881}, 23)

    node_id = "AAAAAAAAAAAAAAAAAAAB"

    list = MlDHT.RoutingTable.Worker.closest_nodes(@name, node_id)
    assert length(list) == 3
  end

  test "if routing table ignores its own node_id", test_worker_context do
    node_id = test_worker_context.node_id
    MlDHT.RoutingTable.Worker.add(@name, node_id, {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "CCCCCCCCCCCCCCCCCCCC", {{127, 0, 0, 1}, 6881}, 23)
    MlDHT.RoutingTable.Worker.add(@name, "DDDDDDDDDDDDDDDDDDDD", {{127, 0, 0, 1}, 6881}, 23)

    assert MlDHT.RoutingTable.Worker.size(@name) == 2
  end

end
