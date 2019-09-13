defmodule MlDHT.Registry do
  require Logger

  @name __MODULE__

  @moduledoc ~S"""
  This module just capsules functions that avoid boilerplate when using the
  MlDHT Registry. (They are not callbacks)
  """

  def start(), do: Registry.start_link(keys: :unique, name: @name)


  def unregister(name), do: Registry.unregister(@name, name)


  def lookup(name), do: Registry.lookup(@name, name)


  def via(name), do: {:via, Registry, {@name, name}}
  def via(node_id_enc, module), do: id(node_id_enc, module) |> via()
  def via(node_id_enc, module, id), do: id(node_id_enc, module, id) |> via()

  def get_pid(name) do
    case Registry.lookup(@name, name) do
      [{pid, _}] -> pid
      _e ->
        Logger.debug "Could not find Process with name #{name} in MlDHT.Registry"
        nil
    end
  end
  def get_pid(node_id_enc, module), do: id(node_id_enc, module) |> get_pid()
  def get_pid(node_id_enc, module, id), do: id(node_id_enc, module, id) |> get_pid()


  defp id(node_id_enc, module) do
    node_id_enc |> Kernel.<>("_" <> Atom.to_string(module))
  end
  defp id(node_id_enc, module, id) when is_atom(id) do
    id(node_id_enc, module, to_string(id))
  end
  defp id(node_id_enc, module, id) do
    id(node_id_enc, module) <> "_" <> id
  end


end
