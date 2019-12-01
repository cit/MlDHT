defmodule MlDHT.Server.Worker.Test do
  use ExUnit.Case

  alias MlDHT.Server.Utils, as: Utils

  test "if handle_info(:change_secret) changes the secret" do
    secret = Utils.gen_secret()
    state = %{old_secret: nil, secret: secret}
    {:noreply, new_state} = MlDHT.Server.Worker.handle_info(:change_secret, state)

    assert new_state.secret != secret
  end


  test "if handle_info(:change_secret) saves the old secret" do
    secret = Utils.gen_secret()
    state = %{old_secret: nil, secret: secret}
    {:noreply, new_state} = MlDHT.Server.Worker.handle_info(:change_secret, state)

    assert new_state.old_secret == secret
  end

end
