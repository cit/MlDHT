defmodule MlDHT.Supervisor do
  use Supervisor

 @moduledoc ~S"""
  Root Supervisor for MlDHT

  """

  @doc false
  # TODO: use Keyword.fetch!/2 to enforce the :node_id option
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, {:ok, opts[:node_id]}, opts)
  end

  @impl true
  def init({:ok, node_id}) do
    node_id_enc = node_id |> Base.encode16()

    children = [
      {DynamicSupervisor,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.RoutingTable.Supervisor),
       strategy: :one_for_one},

      {MlDHT.Search.Supervisor,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Search.Supervisor),
       strategy: :one_for_one},

      {MlDHT.Server.Worker,
       node_id: node_id,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Server.Worker)},

      {MlDHT.Server.Storage,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Server.Storage)},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end


end
