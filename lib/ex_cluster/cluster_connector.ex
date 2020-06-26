defmodule ExCluster.ClusterConnector do
  use GenServer
  require Logger

  alias ExCluster.OrderRegistry
  alias ExCluster.OrderSupervisor

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    Logger.info(fn ->
      "Starting ClusterConnector"
    end)

    :net_kernel.monitor_nodes(true, node_type: :visible)
    {:ok, nil}
  end

  def handle_info({:nodeup, node, node_type}, state) do
    Logger.info(fn ->
      "Node up state: #{inspect(state)}, node: #{inspect(node)}, node_type: #{inspect(node_type)}"
    end)

    set_members(OrderRegistry)
    set_members(OrderSupervisor)

    sleep_interval = Enum.random(100..4_000)
    Process.sleep(sleep_interval)
    setup_state_handoff()
    {:noreply, state}
  end

  def handle_info({:nodedown, node, node_type}, state) do
    Logger.info(fn ->
      "Node down state: #{inspect(state)}, node: #{inspect(node)}, node_type: #{inspect(node_type)}"
    end)

    set_members(OrderRegistry)
    set_members(OrderSupervisor)

    sleep_interval = Enum.random(100..4_000)
    Process.sleep(sleep_interval)

    setup_state_handoff()
    {:noreply, state}
  end

  defp setup_state_handoff do
    Logger.debug(fn ->
      "Setup StateHandoff for nodes: #{inspect(Node.list())}"
    end)

    Node.list()
    |> Enum.each(fn(node) ->
      ExCluster.StateHandoff.join(node)
    end)
  end

  defp set_members(name) do
    members =
      [Node.self() | Node.list()]
      |> Enum.map(fn node ->
        {name, node}
      end)

    :ok = Horde.Cluster.set_members(name, members)
  end
end
