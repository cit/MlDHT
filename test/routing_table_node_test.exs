defmodule RoutingTable.Node.Test do
  use ExUnit.Case

  alias RoutingTable.Node

  test "if RoutingTable.Node starts correctly" do
    pid = Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil})
    assert Process.alive?(pid) == true
  end

  test "if RoutingTable.Node stops correctly" do
    pid = Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil})
    Node.stop(pid)
    assert Process.alive?(pid) == false
  end

  test "if RoutingTable.Node returns goodness (:questionable) correctly" do
    pid = Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil})
    Node.goodness(pid, :questionable)
    assert Node.is_questionable?(pid) == true
  end

  test "if RoutingTable.Node returns goodness (:good) correctly" do
    pid = Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil})
    assert Node.is_good?(pid) == true
  end

  test "if RoutingTable.Node returns last_time_responded correctly" do
    pid = Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil})
    :timer.sleep(1000)
    assert Node.last_time_responded(pid) >= 1
  end

  test "if RoutingTable.Node returns last_query_recv correctly" do
    pid = Node.start_link("AA", {"BB", {{127, 0, 0, 1}, 6881}, nil})
    Node.update(pid, :last_query_rcv)
    :timer.sleep(1000)
    assert (:os.system_time(:seconds) - Node.last_time_queried(pid)) >= 1
  end

end
