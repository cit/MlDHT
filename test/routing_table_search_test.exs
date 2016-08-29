defmodule RoutingTable.Search.Test do
  use ExUnit.Case

  alias RoutingTable.Search

  test "tid_to_process_name" do
    assert Search.tid_to_process_name(<<183, 2>>) == :search1832
    assert Search.tid_to_process_name(<<2, 255, 0, 42>>) == :search2255042
  end

end
