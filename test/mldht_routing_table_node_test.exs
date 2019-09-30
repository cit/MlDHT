defmodule MlDHT.RoutingTable.Node.Test do
  use ExUnit.Case

  alias MlDHT.RoutingTable.Node

  setup do
    rt_name     = "rt_test"
    node_id     = String.duplicate("A", 20)
    node_id_enc = Base.encode16(node_id)
    node_tuple  = {node_id, {{127, 0, 0, 1}, 2323}, nil}
    node_child  = {Node, own_node_id: node_id, node_tuple: node_tuple, bucket_index: 23}

    start_supervised!({
      DynamicSupervisor,
      name: MlDHT.Registry.via(node_id_enc, MlDHT.RoutingTable.NodeSupervisor, rt_name),
      strategy: :one_for_one})

    sup_pid = MlDHT.Registry.get_pid(node_id_enc, MlDHT.RoutingTable.NodeSupervisor, rt_name)
    {:ok, pid} = DynamicSupervisor.start_child(sup_pid, node_child)

    [pid:         pid,
     node_id:     node_id,
     node_id_enc: node_id_enc
    ]
  end

  test "if RoutingTable.Node stops correctly ", state do
    Node.stop(state.pid)
    assert Process.alive?(state.pid) == false
  end


  test "if RoutingTable.Node returns socket correctly ", state do
    assert Node.socket(state.pid) == nil
  end


  test "if RoutingTable.Node returns node_id correctly ", state do
    assert Node.id(state.pid) == state.node_id
  end

  test "if RoutingTable.Node returns goodness correctly ", state do
    assert Node.goodness(state.pid) == :good
  end

  test "if is_good?/1 returns true after the start", state do
    assert Node.is_good?(state.pid) == true
  end

  test "if is_questionable?/1 returns false after the start", state do
    assert Node.is_questionable?(state.pid) == false
  end

  test "if is_questionable?/1 returns true after change", state do
    Node.goodness(state.pid, :questionable)
    assert Node.is_questionable?(state.pid) == true
  end

  test "if RoutingTable.Node returns bucket_index correctly ", state do
    assert Node.bucket_index(state.pid) == 23
  end

  test "if RoutingTable.Node returns node_tuple correctly ", state do
    assert Node.to_tuple(state.pid) == {"AAAAAAAAAAAAAAAAAAAA", {127, 0, 0, 1}, 2323}
  end

  test "if RoutingTable.Node returns bucket_index correctly after change ", state do
    Node.bucket_index(state.pid, 42)
    assert Node.bucket_index(state.pid) == 42
  end


end
