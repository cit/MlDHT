defmodule KRPCProtocol.Decoder.Test do
  use ExUnit.Case, async: true
  doctest KRPCProtocol.Decoder

  def node_id,   do: String.duplicate("a", 20)
  def info_hash, do: String.duplicate("b", 20)

  ##################
  # Error Messages #
  ##################

  test "Error Messages" do
    result = {:error, %{code: 202, msg: "Server Error", tid: "aa"}}
    assert KRPCProtocol.decode("d1:eli202e12:Server Errore1:t2:aa1:y1:ee") == result

    result = {:error, %{code: 201, msg: "A Generic Error Ocurred", tid: "aa"}}
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
    result = {:find_node, %{node_id: "AAA", target: "BBB", tid: "aa"}}
    bin = "d1:ad2:id3:AAA6:target3:BBBe1:q9:find_node1:t2:aa1:y1:qe"

    assert KRPCProtocol.decode(bin) == result
  end

  test "Get_Peers request" do
    result = {:get_peers, %{node_id: "AAA", info_hash: "BBB", tid: "aa"}}
    bin = "d1:ad2:id3:AAA9:info_hash3:BBBe1:q9:get_peers1:t2:aa1:y1:qe"

    assert KRPCProtocol.decode(bin) == result
  end


end
