defmodule ExCluster.ClusterConnector do
  use GenServer
  require Logger

  alias ExCluster.OrderRegistry
  alias ExCluster.OrderSupervisor

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, nil}
  end

  def handle_info({:nodeup, _node, _node_type}, state) do
    Logger.debug(fn ->
      "Node up #{inspect(state)}"
    end)

    set_members(OrderRegistry)
    set_members(OrderSupervisor)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node, _node_type}, state) do
    Logger.debug(fn ->
      "Node down #{inspect(state)}"
    end)

    set_members(OrderRegistry)
    set_members(OrderSupervisor)
    {:noreply, state}
  end

  defp set_members(name) do
    members =
      [Node.self() | Node.list()]
      |> Enum.map(fn node -> {name, node} end)

    :ok = Horde.Cluster.set_members(name, members)
  end
end
