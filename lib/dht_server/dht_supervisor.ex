defmodule MlDHT.Supervisor do
  use Supervisor

 @moduledoc ~S"""
  Root Supervisor for MlDHT


  """

  defp routing_table_for(ip_version) do
    if Application.get_env(:mldht, ip_version) do
      worker(RoutingTable.Worker, [ip_version], [id: ip_version])
    end
  end

  @doc false
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    ## Define workers and child supervisors to be supervised

    ## According to BEP 32 there are two distinct DHTs: the IPv4 DHT, and the
    ## IPv6 DHT. This means we need two seperate routing tables for each IP
    ## version.
    children = [] ++ [routing_table_for(:ipv4)] ++ [routing_table_for(:ipv6)]

    children = children ++ [
      worker(DHTServer.Worker,  []),
      worker(DHTServer.Storage, [])
    ]

    children = Enum.filter(children, fn (v) -> v != nil end)

    Supervisor.init(children, strategy: :one_for_one)
  end

end
