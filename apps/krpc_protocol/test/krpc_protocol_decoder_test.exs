defmodule KRPCProtocol.Decoder.Test do
  use ExUnit.Case, async: true
  doctest KRPCProtocol.Decoder

  ##################
  # Error Messages #
  ##################

  test "202 Error Message" do
    result = {:error, %{code: 202, msg: "Server Error"}}

    assert KRPCProtocol.decode("d1:eli202e12:Server Errore1:t2:aa1:y1:ee") == result
    assert KRPCProtocol.decode("d1:eli202e12:Server Errore1:y1:ee") == result
  end

  test "201 Generic Error Message" do
    result = {:error, %{code: 201, msg: "A Generic Error Ocurred"}}

    assert KRPCProtocol.decode("d1:eli201e23:A Generic Error Ocurrede1:t2:aa1:y1:ee") == result
    assert KRPCProtocol.decode("d1:eli201e23:A Generic Error Ocurrede1:y1:ee") == result
  end

  ########
  # Ping #
  ########

  test "Ping" do
    result = {:ping, %{node_id: "414141"}}

    assert KRPCProtocol.decode("d1:ad2:id3:AAAe1:q4:ping1:y1:qe") == result
    assert KRPCProtocol.decode("d1:ad2:id3:AAAe1:q4:ping1:t2:aa1:y1:qe") == result
  end


  ##############
  # Ping Reply #
  ##############

  test "Ping Reply" do
    result = {:ping_reply, %{node_id: "AAAAAAAAAAAAAAAAAAAA"}}
    bin = "d1:rd2:id20:AAAAAAAAAAAAAAAAAAAAe1:t2:aa1:y1:re"
    assert KRPCProtocol.decode(bin) == result

    bin = "d1:rd2:id20:AAAAAAAAAAAAAAAAAAAAe1:y1:re"
    assert KRPCProtocol.decode(bin) == result

    bin = "d1:rd2:id20:AAAAAAAAAAAAAAAAAAAA1:v3:ABCe1:y1:re"
    assert KRPCProtocol.decode(bin) == result

    bin = "d1:rd2:id20:AAAAAAAAAAAAAAAAAAAAe1:v3:ABC1:y1:re"
    assert KRPCProtocol.decode(bin) == result
  end

  #############
  # Find Node #
  #############

  test "Find Node" do
    result = {:find_node, %{node_id: "AAA", target: "BBB"}}
    bin = "d1:ad2:id3:AAA6:target3:BBBe1:q9:find_node1:t2:aa1:y1:qe"

    assert KRPCProtocol.decode(bin) == result
  end

  test "Get_Peers request" do
    result = {:get_peers, %{node_id: "AAA", info_hash: "BBB"}}
    bin = "d1:ad2:id3:AAA9:info_hash3:BBBe1:q9:get_peers1:y1:qe"

    assert KRPCProtocol.decode(bin) == result
  end


end
