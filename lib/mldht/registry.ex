defmodule MlDHT.Registry do
  require Logger

  @moduledoc ~S"""
  This module just capsules functions that avoid boilerplate when using the
  MlDHT Registry. (They are not callbacks)
  """

  def start(), do: Registry.start_link(keys: :unique, name: MlDHT.Registry)


  def via(name), do: {:via, Registry, {MlDHT.Registry, name}}
  def via(node_id_enc, module), do: id(node_id_enc, module) |> via()
  def via(node_id_enc, module, id), do: id(node_id_enc, module, id) |> via()


  def lookup(name), do: Registry.lookup(MlDHT.Registry, name)


  def get_pid(name) do
    case Registry.lookup(MlDHT.Registry, name) do
      [{pid, _}] -> pid
      e ->
        Logger.error "Could not find Process with name #{name} in MlDHT.Registry"
        require IEx; IEx.pry
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
