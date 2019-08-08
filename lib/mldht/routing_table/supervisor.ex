defmodule MlDHT.RoutingTable.Supervisor do
  use Supervisor
  require Logger

  @moduledoc ~S"""
    TODO
  """

  def start_link(opts) do
    name = MlDHT.Registry.via(opts[:node_id_enc] <> "_" <> opts[:rt_name] <> "_sup")
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(args) do
    node_id     = args[:node_id]
    node_id_enc = args[:node_id_enc]
    rt_name     = args[:rt_name]
    children = [
      {MlDHT.RoutingTable.Worker, rt_name: rt_name,
        node_id: node_id,
        name: MlDHT.Registry.via(node_id_enc <> "_rtable_" <> rt_name <> "_worker")},
      {DynamicSupervisor, name:
        MlDHT.Registry.via(node_id_enc   <> "_rtable_" <> rt_name <> "_nodes_dsup"),
        strategy: :one_for_one}
    ]
    Logger.debug("RoutingTable.Supervisor children #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_one)
  end

end
