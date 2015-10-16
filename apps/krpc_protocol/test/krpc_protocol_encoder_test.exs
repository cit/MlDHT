defmodule KRPCProtocol.Encoder.Test do
  use ExUnit.Case, async: true

  def node_id,   do: String.duplicate("a", 20)
  def info_hash, do: String.duplicate("b", 20)

  def get_peers_str, do: "d1:ad2:id20:" <> node_id <> "9:info_hash20:" <> info_hash

  ###########
  # Queries #
  ###########

  test "KRPCProtocol DHT query ping works" do
    str = KRPCProtocol.encode(:ping, tid: "aa", node_id: node_id)
    assert str == "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaae1:q4:ping1:t2:aa1:y1:qe"
  end

  test "KRPCProtocol DHT query find_node works" do
    str = KRPCProtocol.encode(:find_node, tid: "aa", node_id: node_id, target: info_hash)
    start = "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaa6:target20:bbbbbbbbbbbbbbbbbbbb"
    assert str == start <> "e1:q9:find_node1:t2:aa1:y1:qe"
  end

  test "if query get_peers works" do
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                              tid: "aa")
    result = get_peers_str <> "e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result

    ## With scrape option
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                              scrape: true, tid: "aa")
    result = get_peers_str <> "6:scrapei1ee1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result

    ## With want option
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                              want: "n4", tid: "aa")
    result = get_peers_str <> "4:want2:n4e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result

    ## With scrape and want option
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                              want: "n6", scrape: true, tid: "aa")
    result = get_peers_str <> "6:scrapei1e4:want2:n6e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result
  end

  test "announce_peer query with options" do
    str = KRPCProtocol.encode(:announce_peer, node_id: node_id, info_hash: info_hash,
                              token: "aoeusnth", tid: "aa", implied_port: 1, port: 6881)
    result = "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaa12:implied_porti1e9:info_hash20:bbbbbbbbbbbbbbbbbbbb4:porti6881e5:token8:aoeusnthe1:q13:announce_peer1:t2:aa1:y1:qe"
    assert str == result
  end

end
