# kubernetes-project
Kubernetes Project for ECAM Master 2

## Project purpose
This project is mostly about the setup of the infrastructure around a web service.
We are developping a simple flask api accessbile via web browser.
The app uses data from an external DB.

## Structure overview
The app is accessible from outside via Ingress (reverse proxy).
The app also supports memoization with Varnish
The app is replicated to avoid downtime when updated.
It runs on 3 pods managed by Kubernetes

The DB is sharded, replicated and only accessible on the internal network.

We can monitor the infrastructure from the inside with a grafana dashboard