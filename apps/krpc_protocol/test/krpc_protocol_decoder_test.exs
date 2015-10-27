defmodule KRPCProtocol.Decoder.Test do
  use ExUnit.Case, async: true
  doctest KRPCProtocol.Decoder

  def node_id,   do: String.duplicate("a", 20)
  def info_hash, do: String.duplicate("b", 20)

  #####################
  # Corrupted packets #
  #####################

  test "Invalid bencoded message" do
    assert {:ignore, _} = KRPCProtocol.decode("abcdefgh")
  end

  test "Valid bencoded message, but not a valid DHT message" do
    assert {:ignore, _} = KRPCProtocol.decode(<<100, 49, 58, 118, 52, 58, 76, 84, 1, 1, 101>>)
  end


  ##################
  # Error Messages #
  ##################

  test "Error Messages" do
    result = {:error_reply, %{code: 202, msg: "Server Error", tid: "aa"}}
    assert KRPCProtocol.decode("d1:eli202e12:Server Errore1:t2:aa1:y1:ee") == result

    result = {:error_reply, %{code: 201, msg: "A Generic Error Ocurred", tid: "aa"}}
    assert KRPCProtocol.decode("d1:eli201e23:A Generic Error Ocurrede1:t2:aa1:y1:ee") == result
  end

  ########
  # Ping #
  ########

  test "Ping" do
    result = {:ping, %{node_id: "AAA", tid: "aa"}}
    assert KRPCProtocol.decode("d1:ad2:id3:AAAe1:q4:ping1:t2:aa1:y1:qe") == result
  end


  ##############
  # Ping Reply #
  ##############

  test "Ping Reply" do
    result = {:ping_reply, %{node_id: "AAAAAAAAAAAAAAAAAAAA", tid: "aa"}}
    bin = "d1:rd2:id20:AAAAAAAAAAAAAAAAAAAAe1:t2:aa1:y1:re"
    assert KRPCProtocol.decode(bin) == result
  end

  #############
  # Find Node #
  #############

  test "Find Node" do
    ## valid find_node
    result = {:find_node, %{node_id: "AAA", target: "BBB", tid: "aa"}}
    bin = "d1:ad2:id3:AAA6:target3:BBBe1:q9:find_node1:t2:aa1:y1:qe"
    assert KRPCProtocol.decode(bin) == result

    ## find_node without target
    bin = "d1:ad2:id3:AAAe1:q9:find_node1:t2:aa1:y1:qe"
    assert {:error, _} = KRPCProtocol.decode(bin)
  end

  test "Get_Peers request" do
    ## valid get_peers
    result = {:get_peers, %{node_id: "AAA", info_hash: "BBB", tid: "aa"}}
    bin = "d1:ad2:id3:AAA9:info_hash3:BBBe1:q9:get_peers1:t2:aa1:y1:qe"
    assert KRPCProtocol.decode(bin) == result

    ## get_peers without infohash
    bin = "d1:ad2:id3:AAAe1:q9:get_peers1:t2:aa1:y1:qe"
    assert {:error, _} = KRPCProtocol.decode(bin)
  end


end
