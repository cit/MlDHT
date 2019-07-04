defmodule MlDHT.Supervisor do
  use Supervisor

 @moduledoc ~S"""
  Root Supervisor for MlDHT

  """

  @doc false
  #TODO: use Keyword.fetch!/2 to enforce the :node_id option
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, {:ok, opts[:node_id]}, opts)
  end

  @impl true
  def init({:ok, node_id}) do
    node_id_enc = Base.encode16 node_id
    children = [
      {DynamicSupervisor,
        name: MlDHT.Registry.via(node_id_enc <> "_rtable_dsup"),
        strategy: :one_for_one},
      {DHTServer.Worker,
        node_id: node_id,
        name: MlDHT.Registry.via(node_id_enc <> "_worker")},
      worker(DHTServer.Storage, []), # TODO: pass a name to Storage and allow multiple Storages (see Worker)
    ]

    IO.inspect(children, label: "MlDHT.Supervisor children")

    Supervisor.init(children, strategy: :one_for_one)
  end

end
