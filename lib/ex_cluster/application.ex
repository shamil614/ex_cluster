defmodule ExCluster.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  require Logger

  use Application

  def start(_type, _args) do
    children =
      [
        ExCluster.StateHandoff,
        ExCluster.OrderRegistry,
        ExCluster.OrderSupervisor,

        ExCluster.ClusterConnector
      ]
      |> maybe_start_cluster_supervisor(Mix.env())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExCluster.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_start_cluster_supervisor(children, :test), do: children

  defp maybe_start_cluster_supervisor(children, _) do
    [{Cluster.Supervisor, [Application.get_env(:libcluster, :topologies)]} | children]
  end
end
