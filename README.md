# MlDHT - Mainline Distributed Hash Table
[![Build Status](https://travis-ci.org/cit/MlDHT.svg)](https://travis-ci.org/cit/MlDHT)

A Distributed Hash Table (DHT) is a storage and lookup system that is based on a peer-to-peer (P2P) system. The file sharing protocol BitTorrent makes use of a DHT to find new peers without using a central tracker. There are three popular DHT-based protocols: [KAD](https://en.wikipedia.org/wiki/Kad_network), [Vuze DHT](http://wiki.vuze.com/w/Distributed_hash_table) and Mainline DHT. All protocols are based on [Kademlia](https://en.wikipedia.org/wiki/Kademlia) but are not compatible with each other. The mainline DHT is by far the biggest overlay network with around 15-27 million users per day.

MlDHT, in particular, is an [elixir](http://elixir-lang.org/) package that provides a mainline DHT implementation according to [BEP 05](http://www.bittorrent.org/beps/bep_0005.html). It is build on the following modules:

  * `DHTServer` - main interface, receives all incoming messages;
  * `RoutingTable` - maintains contact information of close nodes.

## Getting Started

Learn how to add MlDHT to your Elixir project and start using it.

### Adding MlDHT To Your Project

To use MlDHT with your projects, edit your `mix.exs` file and add it as a dependency:

```elixir
defp application do
  [applications: [:mldht]]
end

defp deps do
  [{:mldht, "~> 0.0.3"}]
end
```

### Basic Usage

If the application is loaded it automatically bootstraps itself into the overlay network. It does this by starting a `find_node` search for a node that belongs to the same bucket as our own node id. In `mix.exs` you will find the boostrapping nodes that will be used for that first search. By doing this, we will quickly collect nodes that are close to us.

You can use the following function to find nodes for a specific BitTorrent infohash (e.g. Ubuntu 19.04):

```elixir
iex> "D540FC48EB12F2833163EED6421D449DD8F1CE1F"
     |> Base.decode16!
     |> MlDHT.search(fn(node) -> IO.puts "#{inspect node}" end)
```

If you would like to search for nodes and announce yourself to the DHT network use the following function:

```elixir
iex> "D540FC48EB12F2833163EED6421D449DD8F1CE1F"
     |> Base.decode16!
     |> MlDHT.search_announce(6881, fn(node) -> IO.puts "#{inspect node}" end)
```

It is also possible search and announce yourself to the DHT network without a TCP port. By doing this, the source port of the UDP packet should be used instead.

```elixir
iex> "D540FC48EB12F2833163EED6421D449DD8F1CE1F"
     |> Base.decode16!
     |> MlDHT.search_announce(fn(node) -> IO.puts "#{inspect node}" end)
```

## License

MlDHT source code is released under MIT License.
Check LICENSE file for more information.