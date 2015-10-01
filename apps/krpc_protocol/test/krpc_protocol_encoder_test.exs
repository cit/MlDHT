defmodule KRPCProtocol.Encoder.Test do
  use ExUnit.Case, async: true

  def node_id,   do: String.duplicate("a", 20)
  def info_hash, do: String.duplicate("b", 20)

  #####
  ## PING Query
  ##

  test "KRPCProtocol DHT query ping works" do
    str = KRPCProtocol.encode(:ping, node_id: node_id)
    assert str == "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaae1:q4:ping1:t2:aa1:y1:qe"
  end

  #####
  ## FIND_NODE Query
  ##

  test "KRPCProtocol DHT query find_node works" do
    str = KRPCProtocol.encode(:find_node, node_id: node_id, target: info_hash)
    assert str == "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaa6:target20:bbbbbbbbbbbbbbbbbbbbe1:q9:find_node1:t2:aa1:y1:qe"
  end

  #####
  ## GET_PEERS Query
  ##

  def get_peers_str, do: "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaa9:info_hash20:bbbbbbbbbbbbbbbbbbbb"

  test "Mainline DHT query get_peers works" do
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash)
    result = get_peers_str <> "e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result
  end

  test "Mainline DHT query get_peers with scrape works" do
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                       scrape: true)
    result = get_peers_str <> "6:scrapei1ee1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result
  end

  test "Mainline DHT query get_peers with want works" do
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                       want: "n4")
    result = get_peers_str <> "4:want2:n4e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result
  end

  test "Mainline DHT query get_peers with want and scrape works" do
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                       want: "n6", scrape: true)
    result = get_peers_str <> "6:scrapei1e4:want2:n6e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result
  end

  test "Mainline DHT query get_peers with scrape and want works" do
    str = KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash,
                       scrape: true, want: "n4")
    result = get_peers_str <> "6:scrapei1e4:want2:n4e1:q9:get_peers1:t2:aa1:y1:qe"
    assert str == result
  end

  test "announce_peer query with options" do
    assert KRPCProtocol.encode(:announce_peer, node_id: node_id, info_hash: info_hash, token: "aoeusnth", implied_port: 1, port: 6881) == "d1:ad2:id20:aaaaaaaaaaaaaaaaaaaa12:implied_porti1e9:info_hash20:bbbbbbbbbbbbbbbbbbbb4:porti6881e5:token8:aoeusnthe1:q13:announce_peer1:t2:aa1:y1:qe"
  end


end
