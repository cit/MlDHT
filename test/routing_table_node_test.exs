defmodule RoutingTable.Node.Test do
  use ExUnit.Case

  alias RoutingTable.Node

  setup do
    own_node_id = "AA"
    node_tuple = {"BB", {{127, 0, 0, 1}, 6881}, nil}
    opts = [own_node_id: own_node_id, node_tuple: node_tuple]
    {:ok, node_pid} = Node.start_link(opts)
    [node_pid: node_pid] ++ opts
  end

  test "if RoutingTable.Node starts correctly", test_node_context do
    pid = test_node_context.node_pid
    assert Process.alive?(pid) == true
  end

  test "if RoutingTable.Node stops correctly", test_node_context do
    pid = test_node_context.node_pid
    Node.stop(pid)
    assert Process.alive?(pid) == false
  end

  test "if RoutingTable.Node returns goodness (:questionable) correctly", test_node_context do
    pid = test_node_context.node_pid
    Node.goodness(pid, :questionable)
    assert Node.is_questionable?(pid) == true
  end

  test "if RoutingTable.Node returns goodness (:good) correctly", test_node_context do
    pid = test_node_context.node_pid
    assert Node.is_good?(pid) == true
  end

  test "if RoutingTable.Node returns last_time_responded correctly", test_node_context do
    pid = test_node_context.node_pid
    :timer.sleep(1000)
    assert Node.last_time_responded(pid) >= 1
  end

  test "if RoutingTable.Node returns last_query_recv correctly", test_node_context do
    pid = test_node_context.node_pid
    Node.update(pid, :last_query_rcv)
    :timer.sleep(1000)
    assert (:os.system_time(:seconds) - Node.last_time_queried(pid)) >= 1
  end

end
