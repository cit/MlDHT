defmodule MlDHT.Server.Storage do
  @moduledoc false

  use GenServer

  require Logger

  #############
  # Constants #
  #############

  ## One minute in milliseconds
  @min_in_ms 60 * 1000

  ## 5 Minutes
  @review_time 5 * @min_in_ms

  ## 30 Minutes
  @node_expired 30 * @min_in_ms

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init([]) do
    Process.send_after(self(), :review_storage, @review_time * 1000)
    {:ok, %{}}
  end

  def put(pid, infohash, ip, port) do
    GenServer.cast(pid, {:put, infohash, ip, port})
  end

  def print(pid) do
    GenServer.cast(pid, :print)
  end

  def has_nodes_for_infohash?(pid, infohash) do
    GenServer.call(pid, {:has_nodes_for_infohash?, infohash})
  end

  def get_nodes(pid, infohash) do
    GenServer.call(pid, {:get_nodes, infohash})
  end

  def handle_info(:review_storage, state) do
    Logger.debug "Review storage"

    ## Restart review timer
    Process.send_after(self(), :review_storage, @review_time * 1000)

    {:noreply, review(Map.keys(state), state)}
  end

  def handle_call({:has_nodes_for_infohash?, infohash}, _from, state) do
    has_keys = Map.has_key?(state, infohash)
    result   = if has_keys, do: Map.get(state, infohash) != [], else: has_keys

    {:reply, result, state}
  end

  def handle_call({:get_nodes, infohash}, _from, state) do
    nodes = state
    |> Map.get(infohash)
    |> Enum.map(fn(x) -> Tuple.delete_at(x, 2) end)
    |> Enum.slice(0..99)

    {:reply, nodes, state}
  end

  def handle_cast({:put, infohash, ip, port}, state) do
    item = {ip, port, :os.system_time(:seconds)}

    new_state =
      if Map.has_key?(state, infohash) do
        index = state
        |> Map.get(infohash)
        |> Enum.find_index(fn(node_tuple) ->
          Tuple.delete_at(node_tuple, 2) == {ip, port}
        end)

        if index do
          Map.update!(state, infohash, fn(x) ->
            List.replace_at(x, index, item)
          end)
        else
          Map.update!(state, infohash, fn(x) ->
            x ++ [item]
          end)
        end

      else
        Map.put(state, infohash, [item])
      end

    {:noreply, new_state}
  end

  def handle_cast(:print, state) do
    Enum.each(Map.keys(state), fn(infohash) ->
      Logger.debug "#{Base.encode16 infohash}"
      Enum.each(Map.get(state, infohash), fn(x) ->
        Logger.debug "  #{inspect x}"
      end)
    end)

    {:noreply, state}
  end

  def review([], result), do: result
  def review([head | tail], result) do
    new = delete_old_nodes(result, head)
    review(tail, new)
  end

  def delete_old_nodes(state, infohash) do
    Map.update!(state, infohash, fn(list) ->
      Enum.filter(list, fn(x) ->
        (:os.system_time(:millisecond) - elem(x, 2)) <= @node_expired
      end)
    end)
  end

end
