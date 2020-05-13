defmodule MlDHT.Search.Node do
  @moduledoc false

  defstruct id: nil, ip: nil, port: nil, token: nil, requested: 0,
    request_sent: 0, responded: false

  def last_time_requested(node) do
    :os.system_time(:millisecond) - node.request_sent
  end
end
