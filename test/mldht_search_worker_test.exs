defmodule MlDHT.Search.Worker.Test do
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

  test "get_peers", state do
    search_pid = state.pid
    |> MlDHT.Search.Supervisor.start_child(:get_peers, nil, state.node_id)

    Search.get_peers(search_pid, target: state.node_id, start_nodes: [])
    assert Search.type(search_pid) == :get_peers
  end

  test "find_node", state do
    search_pid = state.pid
    |> MlDHT.Search.Supervisor.start_child(:find_node, nil, state.node_id)

    Search.find_node(search_pid, target: state.node_id, start_nodes: [])
    assert Search.type(search_pid) == :find_node
  end

  test "find_node shutdown", state do
    search_pid = state.pid
    |> MlDHT.Search.Supervisor.start_child(:find_node, nil, state.node_id)

    Search.find_node(search_pid, target: state.node_id, start_nodes: [])
    Search.stop(search_pid)

    assert Process.alive?(search_pid) == false
  end

  test "if search exists normally and does not restart", state do
    search_pid = state.pid
    |> MlDHT.Search.Supervisor.start_child(:get_peers, nil, state.node_id)

    tid_enc = search_pid
    |> Search.tid()
    |> Base.encode16()

    Search.stop(search_pid)
    assert MlDHT.Registry.get_pid(state.node_id_enc, Search, tid_enc) == nil
  end

end
