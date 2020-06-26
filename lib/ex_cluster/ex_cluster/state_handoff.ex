defmodule ExCluster.StateHandoff do
  @moduledoc """
  Acts as a cache layer to store process state.
  Processes starting up check the CRDTs for data to load into state at startup.
  """

  use GenServer
  require Logger

  ## Client

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
    Notify the CRDT of its neighbor(s).
    Allows CRDTs to communicate with each other and sync their states.
  """
  def join(neighbour_node) do
    Logger.debug("Joining StateHandoff at #{inspect(neighbour_node)}")
    GenServer.cast(__MODULE__, {:set_neighbours, {__MODULE__, neighbour_node}}, 10_000)
  end

  @doc """
    Passes the customer and order for a state handoff.
  """
  def save(customer, order) do
    GenServer.call(__MODULE__, {:save, customer, order})
  end

  @doc """
    Fetches the cached order data by customer for reloading state.
  """
  def load(customer) do
    GenServer.call(__MODULE__, {:load, customer})
  end

  ## Server

  def init(_) do
    {:ok, crdt_pid} = DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, sync_interval: 5)
    {:ok, crdt_pid}
  end

  # other_node is actuall a tuple { __MODULE__, other_node } passed from above,
  #  by using that in GenServer.call we are sending a message to the process
  #  named __MODULE__ on other_node
  def handle_cast({:set_neighbours, {_module, _neighbour_node} = module_node}, from, crdt_pid) do
    spawn(fn ->
      Logger.debug("Sending set_neighbours to #{inspect(module_node)} with #{inspect(crdt_pid)}")
      # pass our crdt pid in a message so that the crdt on other_node can add it as a neighbour
      # expect other_node to send back it's crdt_pid in response
      neighbour_crdt_pid = GenServer.call(module_node, {:ack_set_neighbours, crdt_pid}, 10_000)
      # add other_node's crdt_pid as a neighbour, we need to add both ways so changes in either
      # are reflected across, otherwise it would be one way only
      DeltaCrdt.set_neighbours(crdt_pid, [neighbour_crdt_pid])
    end)
    {:noreply, crdt_pid}
  end

  # the above GenServer.call ends up hitting this callback, but importantly this
  #  callback will run in the other node that was originally being connected to
  def handle_call({:ack_set_neighbours, neighbour_crdt_pid}, from, crdt_pid) do
    Logger.debug(
      "Setting neighbour #{inspect(neighbour_crdt_pid)}, from: #{inspect(from)}, for local #{inspect(crdt_pid)}"
    )

    # add the crdt's as a neighbour, pass back our crdt to the original adding node via a reply
    DeltaCrdt.set_neighbours(crdt_pid, [neighbour_crdt_pid])
    {:reply, crdt_pid, crdt_pid}
  end

  def handle_call({:save, customer, order}, _from, crdt_pid) do
    DeltaCrdt.mutate(crdt_pid, :add, [customer, order])
    Logger.debug("Added #{customer}'s order '#{inspect(order)} to crdt")
    Logger.debug("CRDT: #{inspect(DeltaCrdt.read(crdt_pid))}")
    {:reply, :ok, crdt_pid}
  end

  def handle_call({:load, customer}, _from, crdt_pid) do
    order =
      crdt_pid
      |> DeltaCrdt.read()
      |> Map.get(customer, [])

    Logger.debug("CRDT: #{inspect(DeltaCrdt.read(crdt_pid))}")
    Logger.debug("Picked up #{inspect(order, charlists: :as_lists)} for #{customer}")

    # remove the order data.
    DeltaCrdt.mutate(crdt_pid, :remove, [customer])

    {:reply, order, crdt_pid}
  end
end
