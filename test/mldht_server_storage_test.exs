defmodule MlDHT.Server.Storage.Test do
  use ExUnit.Case
  require Logger

  alias MlDHT.Server.Storage

  setup do
    rt_name = "test_rt"
    node_id_enc = String.duplicate("A", 20) |> Base.encode16
    pname = node_id_enc <> "_storage"

    start_supervised!(
      {DynamicSupervisor,
       name: MlDHT.Registry.via(node_id_enc   <> "_rtable_" <> rt_name <> "_nodes_dsup"),
       strategy: :one_for_one})

    start_supervised!({MlDHT.Server.Storage, name: MlDHT.Registry.via(pname)})

    [pid: MlDHT.Registry.get_pid(pname)]
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
