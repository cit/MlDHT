defmodule RoutingTable.Supervisor do
  use Supervisor

  @moduledoc ~S"""
    TODO
  """

  def start_link(opts) do
    name = MlDHT.Registry.via(opts[:node_id_enc] <> "_" <> opts[:rt_name] <> "_sup")
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(args) do 
    node_id_enc = args[:node_id_enc]
    rt_name     = args[:rt_name]
    children = [
      {RoutingTable.Worker, name:
        MlDHT.Registry.via(node_id_enc <> "_rtable_" <> rt_name <> "_worker")},
      {DynamicSupervisor, name:
        MlDHT.Registry.via(node_id_enc   <> "_rtable_" <> rt_name <> "_nodes_dsup"),
        strategy: :one_for_one}
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
