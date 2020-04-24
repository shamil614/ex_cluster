defmodule ExClusterTest do
  use ExUnit.Case
  doctest ExCluster

  require Logger

  alias ExCluster.{Order, OrderRegistry, OrderSupervisor}

  setup(context) do
    nodes = LocalCluster.start_nodes("cluster-#{:rand.uniform(9_999_999)}", 3)

    for n <- nodes do
      :rpc.call(n, Application, :ensure_all_started, [:ex_cluster])
    end

    context =
      context
      |> Map.put(:nodes, nodes)

    {:ok, context}
  end

  test "greets the world" do
    assert ExCluster.hello() == :world
  end

  test "starts a cluster and adds orders to each node", %{nodes: [n1, n2, _n3] = nodes} do
    start_children(nodes)

    {:ok, pid} = ensure_process_on_node(n1, "Paul")
    {:ok, pid} = ensure_process_on_node(n2, "Joe")

    paul_state = [1, 2]
    :ok = :rpc.call(n1, Order, :add, ["Paul", paul_state])
    assert ^paul_state = :rpc.call(n1, Order, :contents, ["Paul"])

    joe_state = [4, 5, 6]
    :ok = :rpc.call(n2, Order, :add, ["Joe", joe_state])
    assert ^joe_state = :rpc.call(n2, Order, :contents, ["Joe"])
  end

  test "killing a node with a process, restarts on another node without state transfer", %{
    nodes: [n1, n2, _n3] = nodes
  } do
    start_children(nodes)

    {:ok, %{node: pauls_node}} = ensure_process_on_node(n1, "Paul")
    {:ok, _pid} = ensure_process_on_node(n2, "Joe")

    paul_state = [1, 2]
    :ok = :rpc.call(n1, Order, :add, ["Paul", paul_state])
    assert ^paul_state = :rpc.call(n1, Order, :contents, ["Paul"])

    joe_state = [4, 5, 6]
    :ok = :rpc.call(n2, Order, :add, ["Joe", joe_state])
    assert ^joe_state = :rpc.call(n2, Order, :contents, ["Joe"])

    :ok = rpc(pauls_node, :init, :stop, [])
    :ok = wait_for_node_down(pauls_node)

    [available_node | _] = List.delete(nodes, pauls_node)

    {:ok, %{node: pauls_new_node}} = ensure_process_on_node(available_node, "Paul")
    assert pauls_node != pauls_new_node
    assert [] == :rpc.call(available_node, Order, :contents, ["Paul"])
  end

  def wait_for_node_down(node) do
    if Node.ping(node) == :pong do
      :ok
    else
      Logger.debug(fn ->
        "Node #{node} is not down. Retrying...."
      end)

      Process.sleep(100)
      wait_for_node_down(node)
    end
  end

  defp rpc(n, m, f, a) do
    :rpc.block_call(n, m, f, a)
  end

  defp ensure_process_on_node(target, id) do
    pid = rpc(target, Horde.Registry, :whereis_name, [{OrderRegistry, id}])

    if is_pid(pid) do
      found_node = node(pid)

      Logger.debug(fn ->
        "Found: #{id} #{inspect(pid)} on node: #{inspect(found_node)}"
      end)

      {:ok, %{pid: pid, node: found_node, id: id}}
    else
      Logger.debug(fn ->
        "didn't find pid retrying...."
      end)

      Process.sleep(200)
      ensure_process_on_node(target, id)
    end
  end

  defp start_children([n1, n2, _n3] = nodes) do
    reg_members = for n <- nodes, do: {OrderRegistry, n}
    sup_members = for n <- nodes, do: {OrderSupervisor, n}

    for n <- nodes do
      :ok = :rpc.call(n, Horde.Cluster, :set_members, [OrderRegistry, reg_members])
      :ok = :rpc.call(n, Horde.Cluster, :set_members, [OrderSupervisor, sup_members])
    end

    assert {:ok, _pid1} =
             Horde.DynamicSupervisor.start_child(
               {OrderSupervisor, n1},
               {Order, "Paul"}
             )

    assert {:ok, _pid2} =
             Horde.DynamicSupervisor.start_child(
               {OrderSupervisor, n2},
               {Order, "Joe"}
             )
  end
end
