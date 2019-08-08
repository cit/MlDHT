defmodule MlDHT.RoutingTable.Distance do
  @moduledoc false

  require Bitwise

  @doc """
  TODO
  """
  def closest_nodes(nodes, target, n) do
    closest_nodes(nodes, target)
    |> Enum.slice(0..n)
  end

  def closest_nodes(nodes, target) do
    Enum.sort(nodes, fn(x, y) ->
      xor_cmp(x.id, y.id, target, &(&1 < &2))
    end)
  end

  @doc """
  This function gets two node ids, a target node id and a lambda function as an
  argument. It compares the two node ids according to the XOR metric which is
  closer to the target.

    ## Example

        iex> RoutingTable.Worker.xor_compare("A", "a", "F", &(&1 > &2))
        false
  """
  def xor_cmp("", "", "", func), do: func.(0, 0)
  def xor_cmp(node_id_a, node_id_b, target, func) do
    << byte_a      :: 8, rest_a      :: bitstring >> = node_id_a
    << byte_b      :: 8, rest_b      :: bitstring >> = node_id_b
    << byte_target :: 8, rest_target :: bitstring >> = target

    if (byte_a == byte_b) do
      xor_cmp(rest_a, rest_b, rest_target, func)
    else
      xor_a = Bitwise.bxor(byte_a, byte_target)
      xor_b = Bitwise.bxor(byte_b, byte_target)

      func.(xor_a, xor_b)
    end
  end

  @doc """
  This function takes two node ids as binary and returns the bucket
  number in which the node_id belongs as an integer. It counts the
  number of identical bits.

    ## Example

        iex> RoutingTable.find_bucket(<<0b11110000>>, <<0b11111111>>)
        4
  """
  def find_bucket(node_id_a, node_id_b), do: find_bucket(node_id_a, node_id_b, 0)
  def find_bucket("", "", bucket), do: bucket
  def find_bucket(node_id_a, node_id_b, bucket) do
    << bit_a :: 1, rest_a :: bitstring >> = node_id_a
    << bit_b :: 1, rest_b :: bitstring >> = node_id_b

    if bit_a == bit_b do
      find_bucket(rest_a, rest_b, (bucket + 1))
    else
      bucket
    end
  end


  @doc """
  This function gets the number of bits and a node id as an argument and
  generates a new node id. It copies the number of bits from the given node id
  and the last bits it will generate randomly.
  """
  def gen_node_id(nr_of_bits, node_id) do
    nr_rest_bits = 160 - nr_of_bits
    << bits :: size(nr_of_bits),   _ :: size(nr_rest_bits) >> = node_id
    << rest :: size(nr_rest_bits), _ :: size(nr_of_bits)   >> = :crypto.strong_rand_bytes(20)

    << bits :: size(nr_of_bits), rest :: size(nr_rest_bits)>>
  end


end
