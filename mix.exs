defmodule MlDHT.Mixfile do
  use Mix.Project

  def project do
    [app: :mldht,
     version: "0.0.2",
     elixir: "~> 1.2",
     build_embedded:  Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    [mod: {MlDHT, []},
     env: [
       port: 6881,
       ipv4: true,
       ipv6: true,
       bootstrap_nodes: [
         {"32F54E697351FF4AEC29CDBAABF2FBE3467CC267", "router.bittorrent.com",  6881},
         {"EBFF36697351FF4AEC29CDBAABF2FBE3467CC267", "router.utorrent.com",    6881},
         {"9F08E1074F1679137561BAFE2CF62A73A8AFADC7", "dht.transmissionbt.com", 6881},
       ]],
     applications: [:logger]]
  end

  defp deps do
    [{:bencodex,      "~> 1.0.0"},
     {:krpc_protocol, "~> 0.0.4"},
     {:ex_doc,        "~> 0.10",  only: :dev},
     {:pretty_hex,    "~> 0.0.1", only: :dev}
    ]
  end

  defp description do
    """
    Distributed Hash Table (DHT) is a storage and lookup system based on a peer-to-peer (P2P) system. The file sharing protocol BitTorrent makes use of a DHT to find new peers. MLDHT, in particular, is an elixir package that provides a mainline DHT implementation according to BEP 05.
    """
  end

  defp package do
    [name:        :mldht,
     files:       ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Florian Adamsky"],
     licenses:    ["MIT"],
     links:       %{"GitHub" => "https://github.com/cit/MLDHT"}]
  end
end
