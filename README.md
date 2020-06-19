# ExCluster

**Demo app for distributed Elixir via Horde and libCluster**

## Version Dynamic Membership
Building on top of [Version Basic](https://github.com/shamil614/ex_cluster/tree/vBasic). 
This version adds dynamic cluster membership. Which means that each application evaluates the list of nodes in the
cluster on a real time basis. Below is an excerpt from the `version basic`. 

```elixir
# application.ex

def start(_type, _args) do
    children =
      [
        {Horde.Registry,
         [name: ExCluster.OrderRegistry, keys: :unique, members: registry_members()]}, 
```
Keep in mind this code is run once at startup. The `registery_members()` does not get updated when a node joins or 
leaves the cluster.

The major changes are found in `ExCluster.ClusterConnector`.
```elixir
# cluster_connector.ex
def init(_) do
  :net_kernel.monitor_nodes(true, node_type: :visible)
  {:ok, nil}
end

# example handle_callback

def handle_info({:nodeup, _node, _node_type}, state) do
  Logger.debug(fn ->
    "Node up #{inspect(state)}"
  end)

  set_members(OrderRegistry)
  set_members(OrderSupervisor)
  {:noreply, state}
end
```
Above you'll see that the `GenServer` is monitoring for node changes. 
And updating the `OrderRegistry` and `OrderSupervisor`.

Starting up `node1`
`iex --name node1@127.0.0.1 --cookie mycookie -S mix`
 you'll see this in the console:
```
10:14:54.324 [warn]  [libcluster:cluster] unable to connect to :"node2@127.0.0.1"

10:14:54.326 [warn]  [libcluster:cluster] unable to connect to :"node3@127.0.0.1"
```
Obviously the other 2 nodes are not started yet.

Starting up `node2` (in a new terminal)
`iex --name node2@127.0.0.1 --cookie mycookie -S mix`
 you'll see this in the console:
```
10:51:56.575 [info]  [libcluster:cluster] connected to :"node1@127.0.0.1"
 
10:51:56.576 [warn]  [libcluster:cluster] unable to connect to :"node3@127.0.0.1"

```
See that `node2` can connect to `node1` and the makes sense `node1` was up and running when `node2` started.
Go back to the terminal on `node1` and type `Node.list()`
You'll see the following
```elixir
iex(node1@127.0.0.1)1> Node.list
[:"node2@127.0.0.1"]
```

To verify our horde modules have dynamically added peers type
```elixir
iex(node1@127.0.0.1)4> Horde.Cluster.members(ExCluster.OrderRegistry)
[
  {ExCluster.OrderRegistry, :"node1@127.0.0.1"},
  {ExCluster.OrderRegistry, :"node2@127.0.0.1"}
]

```
