defmodule MlDHT.Test do
  use ExUnit.Case

  test "if node_id() returns a String that has a length of 20 characters" do
    node_id = MlDHT.node_id()
    assert byte_size(node_id) == 20
  end

  test "if node_id_enc() returns a String that has a length of 40 characters" do
    node_id_enc = MlDHT.node_id_enc()
    assert String.length(node_id_enc) == 40
  end

end
