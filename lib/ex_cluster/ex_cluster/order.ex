defmodule ExCluster.Order do
  use GenServer
  require Logger

  alias ExCluster.StateHandoff

  def child_spec(customer), do: %{id: customer, start: {__MODULE__, :start_link, [customer]}}

  def start_link(customer) do
    # note the change here in providing a name: instead of [] as the 3rd param
    GenServer.start_link(__MODULE__, customer, name: via_tuple(customer))
  end

  # add contents to the customers order
  def add(customer, new_order_contents) do
    GenServer.cast(via_tuple(customer), {:add, new_order_contents})
  end

  # fetch current contents of the customers order
  def contents(customer) do
    GenServer.call(via_tuple(customer), {:contents})
  end

  defp via_tuple(customer) do
    {:via, Horde.Registry, {ExCluster.OrderRegistry, customer}}
  end

  def init(customer) do
    Process.flag(:trap_exit, true)
    order_contents = StateHandoff.load(customer)

    {:ok, {customer, order_contents}}
  end

  def terminate(reason, {customer, order_contents}) do
    # save state in storage layer
    ExCluster.StateHandoff.save(customer, order_contents)

    :ok
  end

  def handle_cast({:add, new_order_contents}, {customer, order_contents}) do
    {:noreply, {customer, order_contents ++ new_order_contents}}
  end

  def handle_call({:contents}, _from, state = {_, order_contents}) do
    {:reply, order_contents, state}
  end
end
