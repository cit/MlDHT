defmodule MlDHT.RoutingTable.Distance.Test do
  use ExUnit.Case

  alias MlDHT.RoutingTable.Distance

  test "gen_node_id" do
    node_id = String.duplicate("A", 20)
    result  = Distance.gen_node_id(8, node_id)

    assert byte_size(result) == 20
    assert String.first(result) == String.first(node_id)

    result = Distance.gen_node_id(152, node_id)
    assert byte_size(result) == 20
    assert String.starts_with?(result, String.duplicate("A", 19))

    result = Distance.gen_node_id(2, <<85, 65, 186, 187, 3, 126, 81, 52, 54, 56, 37, 227, 187, 54, 221, 198, 79, 194, 129, 1>>)
    assert byte_size(result) == 20
  end

  test "xor_cmp" do
    assert Distance.xor_cmp("A", "a", "F", &(&1 > &2)) == false
    assert Distance.xor_cmp("a", "B", "F", &(&1 > &2)) == true
  end

  test "If the function find_bucket works correctly" do
    assert Distance.find_bucket("abc", "bca") == 6
    assert Distance.find_bucket("bca", "abc") == 6

    assert Distance.find_bucket("AA", "aa") == 2
    assert Distance.find_bucket("aa", "AA") == 2

    assert Distance.find_bucket(<<0b00000010>>, <<0b00000010>>) == 8
    assert Distance.find_bucket(<<0b10000010>>, <<0b00000010>>) == 0
    assert Distance.find_bucket(<<0b11110000>>, <<0b11111111>>) == 4
  end

end
