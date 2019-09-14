defmodule MlDHT.Search.Supervisor do
  use DynamicSupervisor

  require Logger

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, {:ok, opts[:strategy]}, name: opts[:name])
  end

  def init({:ok, strategy}) do
    DynamicSupervisor.init(strategy: strategy)
  end

  def start_child(pid, type, socket, node_id) do
    node_id_enc = Base.encode16(node_id)
    tid         = KRPCProtocol.gen_tid()
    tid_str     = Base.encode16(tid)

    ## If a Search already exist with this tid, generate a new TID by starting
    ## the function again
    if MlDHT.Registry.get_pid(node_id_enc, MlDHT.Search.Worker, tid_str) do
      Logger.error "SAME TID!!!! #{tid_str}"
      start_child(pid, type, socket, node_id)
    else
        {:ok, search_pid} = DynamicSupervisor.start_child(pid,
          {MlDHT.Search.Worker,
           name:    MlDHT.Registry.via(node_id_enc, MlDHT.Search.Worker, tid_str),
           type:    type,
           socket:  socket,
           node_id: node_id,
           tid:     tid})

        search_pid
    end
  end

end
