# ExCluster

**Demo app for distributed Elixir via Horde and libCluster**

## Version Basic
This tagged version demos a basic distributed application. 
The basic version shows how a Supervison tree is setup with Horde, and simple GenServer to hold state.
Application nodes are set **statically**. GenServer **state is not recovered** on crash. 
When a node goes down, the GenServer(s) started by `Horde.DynamicSupervisor` are moved to another node.

## Setup
* From project root `mix deps.get`
* Open a terminal (node1) and run ` iex --name node1@127.0.0.1 --cookie mycookie -S mix`
* Open a terminal (node2) and run ` iex --name node2@127.0.0.1 --cookie mycookie -S mix`
* Open a terminal (node3) and run ` iex --name node3@127.0.0.1 --cookie mycookie -S mix`

## Demo Distributed Elixir and Process monitoring
* Start a GenServer, `ExCluster.Order`, via `Horde.DynamicSupervisor`.
Run the following command in any terminal:
`Horde.DynamicSupervisor.start_child(ExCluster.OrderSupervisor, { ExCluster.Order, "Mark" })`
* The return value should look like `{:ok, #PID<15501.238.0>}`. Look closely at the pid. 
If the first number is anything but a `0` then it means the process was started on a remote node.
* Even though you started the process on node1, take a look at the other terminals (node2, node3). 
They will indicate that a process was started on that node. `11:12:19.729 [info]  Starting Order for Mark`

* Continue starting GenServers until you get a process that shows it was started on a local node.
```
iex> Horde.DynamicSupervisor.start_child(ExCluster.OrderSupervisor, { ExCluster.Order, "Paul" })
{:ok, #PID<15500.279.0>}

iex> Horde.DynamicSupervisor.start_child(ExCluster.OrderSupervisor, { ExCluster.Order, "John" })
{:ok,  #PID<0.350.0>}
```
* The last process indicates that it was started on the local node because of the first `0` in `#PID<0.350.0>`
* Give the process some state by adding order contents 
```
iex> Excluster.Order.add("John", [4,5])
:ok
iex> Excluster.Order.contents("John")
[4,5]
```
* Now that a local process is running with state, we can test what happens when the local node goes down. 
In the local node run `:init.stop`
* Look at the other terminals (the nodes that are still alive). One of them should show `Starting Order for John`.
This means the `Cluster.Supervisor` detected the node going down and restarted the process on another node.
* Now check the state of the process:
```
iex> Excluster.Order.contents("John")
[]
```
* Note the empty state: `[]`. While the process was restarted, the state was not restored.



