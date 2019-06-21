defmodule MlDHT.Supervisor do
  use Supervisor

 @moduledoc ~S"""
  Root Supervisor for MlDHT


  """

  @doc false
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    ## Define workers and child supervisors to be supervised

    # ## According to BEP 32 there are two distinct DHTs: the IPv4 DHT, and the
    # ## IPv6 DHT. This means we need two seperate routing tables for each IP
    # ## version.
    # children = [
    #   (if Application.get_env(:mldht, :ipv4) do
    #     {RoutingTable.Supervisor, [:ipv4, name: RoutingTable.IPv4.Supervisor]}
    #   end),
    #   (if Application.get_env(:mldht, :ipv6) do
    #     {RoutingTable.Supervisor, [:ipv6, name: RoutingTable.IPv6.Supervisor]}
    #   end),
    #   {DHTServer.Worker, name: DHTServer.Worker},
    #   worker(DHTServer.Storage, []), # TODO: pass a name to Storage and allow multiple Storages (see Worker)
    # ] |> Enum.reject(&is_nil/1)

    children = [
      {DynamicSupervisor, name: MlDHT.RoutingTablesDynSupervisor, strategy: :one_for_one},
      {DHTServer.Worker, name: DHTServer.Worker},
      worker(DHTServer.Storage, []), # TODO: pass a name to Storage and allow multiple Storages (see Worker)
    ]

    IO.inspect(children, label: "MlDHT.Supervisor children")

    Supervisor.init(children, strategy: :one_for_one)
  end

end
