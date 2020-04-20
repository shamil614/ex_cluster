defmodule ExCluster.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

#  def connect_nodes do
#    # take in list of nodes from the env
#    case System.get_env("NODES") do
#      nodes when is_binary(nodes) ->
#
#        nodes
#        # convert list of nodes into atoms of node names
#        |> String.split(",")
#        |> Enum.map(&String.to_atom/1)
#        |> IO.inspect(label: "Connecting to nodes ==>")
#          # connect to all nodes to make a cluster
#        |> Enum.each(&Node.connect/1)
#      _ ->
#        nil
#    end
#  end

  def start(_type, _args) do
    children = [
      {Horde.Registry, [name: ExCluster.OrderRegistry, keys: :unique, members: registry_members()]},
      {Horde.DynamicSupervisor,
        [name: ExCluster.OrderSupervisor,
          strategy: :one_for_one,
          distribution_strategy: Horde.UniformQuorumDistribution,
          max_restarts: 100_000,
          max_seconds: 1,
          shutdown: 50_000,
          members: supervisor_members()
        ]},
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies)]},
      %{
        id: ExCluster.ClusterConnector,
        restart: :transient,
        start:
          {Task, :start_link,
          [
            fn ->
              Horde.DynamicSupervisor.wait_for_quorum(ExCluster.OrderSupervisor, 30_000)
              Horde.DynamicSupervisor.start_child(ExCluster.OrderSupervisor, ExCluster.Order)
            end
          ]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExCluster.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp registry_members do
    [
      {ExCluster.OrderRegistry, :"node1@127.0.0.1"},
      {ExCluster.OrderRegistry, :"node2@127.0.0.1"},
      {ExCluster.OrderRegistry, :"node3@127.0.0.1"}
    ]
  end

  defp supervisor_members do
    [
      {ExCluster.OrderSupervisor, :"node1@127.0.0.1"},
      {ExCluster.OrderSupervisor, :"node2@127.0.0.1"},
      {ExCluster.OrderSupervisor, :"node3@127.0.0.1"}
    ]
  end
end
