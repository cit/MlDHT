defmodule MldhtUmbrella.Mixfile do
  use Mix.Project

  def project do
    [app: :mldht,
     version: "0.1.0",
     apps_path: "apps",
     build_embedded:  Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     package: package,
     deps: deps]
  end

  defp deps do
    []
  end

  defp description do
    """
    Distributed Hash Table (DHT) is a storage and lookup system based on a peer-to-peer (P2P) system. The file sharing protocol BitTorrent makes use of a DHT to find new peers without using a central tracker. There are three popular DHT-based protocols: KAD, Vuze DHT, and Mainline DHT. MLDHT, in particular, is an elixir package that provides a mainline DHT implementation according to BEP 05.
    """
  end

  defp package do
    [name:        :mldht,
     files:       ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     files:       ["apps", "priv", "mix.exs", "README*", "LICENSE*", "license*"],
     maintainers: ["Florian Adamsky"],
     licenses:    ["MIT"],
     links:       %{"GitHub" => "https://github.com/cit/MLDHT"}]
  end
end
