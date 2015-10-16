defmodule KRPCProtocol.Decoder do
  require Logger

  def decode(payload) when is_binary(payload) do
    payload |> Bencodex.decode |> decode
  end

  #########
  # Error #
  #########

  def decode(%{"y" => "e", "t" => tid, "e" => [code, msg]}) do
    {:error, %{code: code, msg: msg, tid: tid}}
  end

  #############
  # Get_Peers #
  #############

  def decode(%{"y" => "q", "t" => tid, "q" => "get_peers",
               "a" => %{"id" => node_id, "info_hash" => info_hash}}) do
    {:get_peers, %{tid: tid, node_id: node_id, info_hash: info_hash}}
  end

  #############
  # Find Node #
  #############

  def decode(%{"y" => "q", "t" => tid, "q" => "find_node", "a" => %{"id" => node_id, "target" => target}}) do
    {:find_node, %{node_id: node_id, target: target, tid: tid}}
  end


  ## Extract nodes and values from the DHT response and create a list
  ## of it. If values are empty, it will create an empty list.
  # def decode(%{"y" => status, "r" => param_map}, result) when status == "r" do

  def decode(%{"y" => "r", "t" => tid, "r" => %{"id" => node_id, "nodes" => nodes} }) do
    {:find_node_reply, %{tid: tid, node_id: node_id, nodes: extract_nodes(nodes)}}
  end

  ########
  # Ping #
  ########

  def decode(%{"q" => "ping", "t" => tid, "y" => "q", "a" => %{"id" => node_id}}) do
    {:ping, %{node_id: node_id, tid: tid}}
  end

  ##############
  # Ping Reply #
  ##############

  def decode(%{"y" => "r", "t" => tid, "r" => %{"id" => node_id}}) do
    {:ping_reply, %{node_id: node_id, tid: tid}}
  end


    @doc """
  This function extracts the Ipv4 address from a 'get_peers' response
  which are sharing the given infohash. (values)
  """
  def extract_values(nil), do: []

  def extract_values(nodes), do: extract_values(nodes, [])

  def extract_values([], result), do: result

  def extract_values([addr | tail], result) do
    extract_values(tail, result ++ [compact_format(addr)])
  end

  @doc """
  This function takes the nodes element and extracts all the IPv4
  nodes and returns it as a list.
  """
  def extract_nodes(nil), do: []

  def extract_nodes(nodes), do: extract_nodes(nodes, [])

  def extract_nodes(<<>>, result), do: result

  def extract_nodes(<<id :: binary-size(20), addr :: binary-size(6),
                    tail :: binary>>, result) do
    extract_nodes(tail, result ++ [{id, compact_format(addr)}])
  end

  @doc """
  This function takes a byte string which is encoded in compact format
  and extracts the socket address (IPv4, port) and returns it.
  """
  def compact_format(<<ipv4 :: binary-size(4), port :: size(16) >>) do
    << oct1 :: size(8), oct2 :: size(8),
    oct3 :: size(8), oct4 :: size(8) >> = ipv4
    {{oct1, oct2, oct3, oct4}, port}
  end

end
