
# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, handle_sasl_reports: true, level: :debug

config :libcluster, :topologies,
  cluster: [
    strategy: Cluster.Strategy.Epmd,
    config: [
      hosts: [:"node1@127.0.0.1", :"node2@127.0.0.1", :"node3@127.0.0.1"]
    ]
  ]
