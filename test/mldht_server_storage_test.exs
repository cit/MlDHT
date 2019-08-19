defmodule MlDHT.Server.Storage.Test do
  use ExUnit.Case
  require Logger

  alias MlDHT.Server.Storage
  alias MlDHT.Registry

  setup do
    node_id_enc = String.duplicate("A", 20) |> Base.encode16()
    rt_name = "test_rt"

    start_supervised!({
      DynamicSupervisor,
      name: Registry.via(node_id_enc, MlDHT.RoutingTable.NodeSupervisor, rt_name),
      strategy: :one_for_one})

    start_supervised!({Storage, name: Registry.via(node_id_enc, Storage)})

    [pid: MlDHT.Registry.get_pid(node_id_enc, Storage)]
  end

  test "has_nodes_for_infohash?", test_context do
    pid = test_context.pid
    Storage.put(pid, "aaaa", {127, 0, 0, 1}, 6881)

    assert Storage.has_nodes_for_infohash?(pid, "bbbb") == false
    assert Storage.has_nodes_for_infohash?(pid, "aaaa") == true
  end

  test "get_nodes", test_context do
    pid = test_context.pid

    Storage.put(pid, "aaaa", {127, 0, 0, 1}, 6881)
    Storage.put(pid, "aaaa", {127, 0, 0, 1}, 6881)
    Storage.put(pid, "aaaa", {127, 0, 0, 2}, 6882)

    Storage.print(pid)

    assert Storage.get_nodes(pid, "aaaa") == [{{127,0,0,1}, 6881}, {{127, 0, 0, 2}, 6882}]
  end

end
