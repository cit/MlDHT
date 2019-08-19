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
    node_id_enc = MlDHT.node_id_enc()

    children = [
      {DynamicSupervisor,
        name: MlDHT.Registry.via(node_id_enc, MlDHT.RoutingTable.Supervisor),
        strategy: :one_for_one},

      {MlDHT.Server.Worker,
       node_id: node_id,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Server.Worker)},

      {MlDHT.Server.Storage,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Server.Storage)},
    ]

    IO.inspect(children, label: "MlDHT.Supervisor children")
    Supervisor.init(children, strategy: :one_for_one)
  end


end
