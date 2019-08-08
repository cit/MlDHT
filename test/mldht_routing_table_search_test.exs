defmodule MlDHT.RoutingTable.Search.Test do
  use ExUnit.Case

  alias MlDHT.RoutingTable.Search

  test "tid_to_process_name" do
    assert Search.tid_to_process_name(<<183, 2>>)        == :search183_2
    assert Search.tid_to_process_name(<<2, 255, 0, 42>>) == :search2_255_0_42
  end

  test "is_active?" do
    assert Search.is_active?(<<183, 2>>)   == false
    assert Search.is_active?(:search183_2) == false

    pname = Search.start_link(nil, "aa")
    assert Search.is_active?(pname) == true
  end

  test "stop" do
    pname = Search.start_link(nil, "aa")
    Search.find_node(pname, target: "bb", start_nodes: [])
    Search.stop(pname)
    assert Search.is_active?(pname) == false
  end

  test "get_peers" do
    pname = Search.start_link(nil, "aa")
    Search.get_peers(pname, target: "bb", start_nodes: [])
    assert Search.is_active?(pname) == true
  end

  test "find_node" do
    pname = Search.start_link(nil, "aa")
    Search.find_node(pname, target: "bb", start_nodes: [])
    assert Search.is_active?(pname) == true
  end

  test "type" do
    ## get_peers
    pname = Search.start_link(nil, "aa")
    Search.get_peers(pname, target: "bb", start_nodes: [])
    assert Search.type(pname) == :get_peers

    ## find_node
    pname = Search.start_link(nil, "aa")
    Search.find_node(pname, target: "bb", start_nodes: [])
    assert Search.type(pname) == :find_node
  end



end
