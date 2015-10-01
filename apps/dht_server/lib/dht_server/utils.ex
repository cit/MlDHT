defmodule DHTServer.Utils do

  @doc ~S"""
  This function gets a tuple as IP address and a port and returns a
  string which contains the IPv4 address and port in the following
  format: "127.0.0.1:6881".

    ## Example
    iex> DHTServer.Utils.tuple_to_ipstr({127, 0, 0, 1}, 6881)
    "127.0.0.1:6881"
  """
  def tuple_to_ipstr({oct1, oct2, oct3, oct4}, port) do
    "#{oct1}.#{oct2}.#{oct3}.#{oct4}:#{port}"
  end

  @doc ~S"""
  This function gets a tuple as IP address and a port and returns a
  string which contains the IPv4 address and port in the following
  format: "127.0.0.1:6881".

    ## Example
    iex> DHTServer.Utils.ipstr_to_tuple("127.0.0.1")
    {127, 0, 0, 1}
  """
  def ipstr_to_tuple(ip_str) do
    String.split(ip_str, ".")
    |> Enum.map(fn(x) -> String.to_integer(x) end)
    |> List.to_tuple
  end


  @doc ~S"""
  This function generates a 160 bit (20 byte) random node id as a
  binary.
  """
  def gen_node_id() do
    :random.seed(:erlang.now)

    Stream.repeatedly(fn -> :random.uniform 255 end)
    |> Enum.take(20)
    |> :binary.list_to_bin
  end

end
