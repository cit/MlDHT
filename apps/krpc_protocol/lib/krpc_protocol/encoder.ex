defmodule KRPCProtocol.Encoder do

  defp gen_dht_query(command, options) when is_map(options) do
    Bencodex.encode %{
      "t" => "aa",
      "y" => "q",
      "q" => command,
      "a" => options
    }
  end

  defp gen_dht_response(options) when is_map(options) do
    Bencodex.encode %{
      "t" => "aa",
      "y" => "r",
      "r" => options
    }
  end

  defp gen_dht_query(options, command) when is_map(options) do
    gen_dht_query command, options
  end

  #####
  ## PING Query
  ##

  def encode(:ping, node_id: node_id) do
    gen_dht_query "ping", %{"id" => node_id}
  end

  def encode(:ping_reply, node_id: node_id) do
    gen_dht_response %{"id" => node_id}
  end

  #####
  ## FIND_NODE Query
  ##

  @doc ~S"""
  This function returns a bencoded Mainline DHT find_node query. It
  needs a 20 bytes node id and a 20 bytes target id as an argument.

  ## Example
  iex> KRPCProtocol.encode(:find_node, node_id: node_id, target: info_hash)
  """
  def encode(:find_node, node_id: id, target: target) do
    gen_dht_query "find_node", %{"id" => id, "target" => target}
  end

  def encode(:find_node_reply, node_id: id, nodes: nodes) do
    gen_dht_response %{"id" => id, "nodes" => compact_format(nodes)}
  end


  def compact_format(nodes), do: compact_format(nodes, "")
  def compact_format([], result), do: result
  def compact_format([head | tail], result) do
    {node_id, ip, port} = head
    result = result <> <<node_id :: size(160), ip :: size(48), port :: size(16)>>

    compact_format(tail, result)
  end


  #####
  ## GET_PEERS Query
  ##

  defp query_dict(id, info_hash) do
    %{"id" => id, "info_hash" => info_hash}
  end

  @doc ~S"""
  This function returns a bencoded Mainline DHT get_peers query. It
  needs a 20 bytes node id and a 20 bytes info_hash as an
  argument. Optional arguments are [want: "n6", scrape: true]

  ## Example
  iex> KRPCProtocol.encode(:get_peers, node_id: node_id, info_hash: info_hash)
  """

  defp add_option_if_defined(dict, _key, nil), do: dict
  defp add_option_if_defined(dict, key, value) do
    if value == true do
      Dict.put_new(dict, to_string(key), 1)
    else
      Dict.put_new(dict, to_string(key), value)
    end
  end

  def encode(:get_peers, args) do
    query_dict(args[:node_id], args[:info_hash])
    |> add_option_if_defined(:scrape, args[:scrape])
    |> add_option_if_defined(:noseed, args[:noseed])
    |> add_option_if_defined(:want, args[:want])
    |> gen_dht_query("get_peers")
  end

  #####
  ## ANNOUNCE_PEER Query
  ##

  @doc ~S"""
  This function returns a bencoded Mainline DHT get_peers query. It
  needs a 20 bytes node id and a 20 bytes info_hash as an
  argument. Optional arguments are [: "n6", scrape: true]

  ## Example
  iex> KRPCProtocol.encode(:announce_peer, node_id: node_id, info_hash: info_hash)
  """

  def encode(:announce_peer, args) do
    query_dict(args[:node_id], args[:info_hash])
    |> Dict.put_new("implied_port", args[:implied_port])
    |> Dict.put_new("port", args[:port])
    |> Dict.put_new("token", args[:token])
    |> gen_dht_query("announce_peer")
  end
end
