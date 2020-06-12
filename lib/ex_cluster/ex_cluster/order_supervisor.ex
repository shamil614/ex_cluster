defmodule ExCluster.OrderSupervisor do
  use Horde.DynamicSupervisor

  def start_link(init_arg \\ []) do
    init_arg =
    [
      strategy: :one_for_one,
      distribution_strategy: Horde.UniformQuorumDistribution,
      max_restarts: 100_000,
      max_seconds: 1,
      shutdown: 50_000,
      members: members()
    ]
    |> Keyword.merge(init_arg)
    Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, [name: __MODULE__])
  end

  def init(init_arg) do
    Horde.DynamicSupervisor.init(init_arg)
  end

  defp members() do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end
end
