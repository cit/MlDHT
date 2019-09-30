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

  test "if MlDHT.search returns nodes for ubuntu-19.04.iso.torrent" do
    Process.register self(), :mldht_test_search

    ## Wait 3 seconds to ensure that the bootstrapping process has collected
    ## enough nodes
    :timer.sleep(3000)

    ## The mldht search finds multiple nodes and calls the anonymous functions
    ## therfor also multiple times. After the test was successful the process
    ## :mldht_test_search does not exist anymore, but the function is still get
    ## called. To avoid errors, I wrapped the try-do-rescuce around the send
    ## function.
    "D540FC48EB12F2833163EED6421D449DD8F1CE1F"
    |> Base.decode16!
    |> MlDHT.search(fn (_node) ->
      try do
        send :mldht_test_search, {:called_back, :pong}
      rescue
        _ -> 1 + 1
      end
    end)

    assert_receive {:called_back, :pong}, 40_000
  end

end
