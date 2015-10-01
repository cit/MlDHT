defmodule RoutingTable.Timer do
  use GenServer

  require Logger

  def start_link(dest, msg, time) do
    GenServer.start_link(__MODULE__, [dest, msg, time])
  end

  def init([dest, msg, time]) do
    Logger.debug "Started Timer"
    Process.send_after(dest, msg, time) # In 2 hours
    {:ok, %{}}
  end

end
