defmodule DHTServer.Mixfile do
  use Mix.Project

  def project do
    [app: :dht_server,
     version: "0.0.1",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :routing_table, :krpc_protocol],
     env: [
       bootstrap_nodes: [
         {"32F54E697351FF4AEC29CDBAABF2FBE3467CC267", "router.bittorrent.com",  6881},
         {"EBFF36697351FF4AEC29CDBAABF2FBE3467CC267", "router.utorrent.com",    6881},
         {"9F08E1074F1679137561BAFE2CF62A73A8AFADC7", "dht.transmissionbt.com", 6881},
       ]
     ],
     mod: {DHTServer, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:routing_table, in_umbrella: true},
     {:krpc_protocol, in_umbrella: true},
     {:pretty_hex, "~> 0.0.1"},
    ]
  end
end
