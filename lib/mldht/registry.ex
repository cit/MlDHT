defmodule MlDHT.Registry do

  @moduledoc ~S"""
  This module just capsules functions that avoid boilerplate when using
  the MlDHT Registry.
  (They are not callbacks)
  """

  def start() do
    Registry.start_link(keys: :unique, name: MlDHT.Registry)
  end

  def via(name) do
    {:via, Registry, {MlDHT.Registry, name}}
  end

  def lookup(name) do
    Registry.lookup(MlDHT.Registry, name)
  end

  def get_pid(name) do
    case Registry.lookup(MlDHT.Registry, name) do
      [{pid, _}] -> pid
      e ->
        require IEx; IEx.pry
        raise "Could not find Process with name #{inspect(e)} in MlDHT.Registry"
    end
  end

end
