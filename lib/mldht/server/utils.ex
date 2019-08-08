defmodule MlDHT.Server.Utils do
  @moduledoc false

  @doc ~S"""
  This function gets a tuple as IP address and a port and returns a
  string which contains the IPv4 or IPv6 address and port in the following
  format: "127.0.0.1:6881".

    ## Example
    iex> MlDHT.Server.Utils.tuple_to_ipstr({127, 0, 0, 1}, 6881)
    "127.0.0.1:6881"
  """
  def tuple_to_ipstr({oct1, oct2, oct3, oct4}, port) do
    "#{oct1}.#{oct2}.#{oct3}.#{oct4}:#{port}"
  end

  def tuple_to_ipstr(ipv6_addr, port) when tuple_size(ipv6_addr) == 8 do
    ip_str =
      String.duplicate("~4.16.0B:", 8)
      |> String.slice(0..-2) ## remove last ":" of the string
      |> :io_lib.format(Tuple.to_list(ipv6_addr))
      |> List.to_string

    "[#{ip_str}]:#{port}"
  end

  @doc ~S"""
  This function gets an IPv4 address as binary and converts it to a tuple.

    ## Example
    iex> MlDHT.Server.Utils.ipstr_to_tuple("127.0.0.1")
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
  def gen_node_id do
    :rand.seed(:exs64, :os.timestamp)

    Stream.repeatedly(fn -> :rand.uniform 255 end)
    |> Enum.take(20)
    |> :binary.list_to_bin
  end

  @doc """
  TODO
  """
  def gen_secret, do: gen_node_id()



end
