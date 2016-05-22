defmodule MldhtUmbrella.Mixfile do
  use Mix.Project

  def project do
    [app: :mldht,
     version: "0.1.0",
     apps_path: "apps",
     build_embedded:  Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps folder
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
     files:       ["apps", "priv", "mix.exs", "README*", "LICENSE*", "license*"],
     maintainers: ["Florian Adamsky"],
     licenses:    ["MIT"],
     links:       %{"GitHub" => "https://github.com/cit/MLDHT"}]
  end
end
