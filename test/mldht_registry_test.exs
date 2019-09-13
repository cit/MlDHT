defmodule MlDHT.Registry.Test do
  use ExUnit.Case

  alias MlDHT.Search.Worker, as: Search

  setup do
    node_id     = String.duplicate("A", 20)
    node_id_enc = Base.encode16(node_id)

    start_supervised!(
      {MlDHT.Search.Supervisor,
       name: MlDHT.Registry.via(node_id_enc, MlDHT.Search.Supervisor),
       strategy: :one_for_one})

    [pid:     MlDHT.Registry.get_pid(node_id_enc, MlDHT.Search.Supervisor),
     node_id:     node_id,
     node_id_enc: node_id_enc
    ]
  end

  test "foo", state do
    search_pid = state.pid
    |> MlDHT.Search.Supervisor.start_child(:get_peers, nil, state.node_id)

    tid = Search.tid(search_pid)
    Search.stop(search_pid)
    assert MlDHT.Registry.get_pid(state.node_id_enc, Search, tid) == nil
  end

end
