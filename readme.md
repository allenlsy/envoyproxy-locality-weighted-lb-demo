This repo creates a setup for demonstrating the locality weighted load balancing feature for Envoy proxy.

The components of this demo is as follows:

* A client container: runs Envoy proxy
* Backend container in the same locality as the client, namely local-a. This simulates the scenario that client and server are in the same Kubernetes cluster.
* Backend container in a different locality, namely local-b. This simulates the scenario that backend is in another Kubernetes cluster but the same zone as the client.
* Backend container in yet another locality, namely remote. This simulates the scenario that backend is a different zone from the client.

The client Envoy proxy configures the 3 backend containers in the same service cluster, so that Envoy handle load balancing to those backend servers. Please refer to the configuration in [`configs/cds.yaml`](configs/cds.yaml)

```shell
# Start demo
docker-compose -p demo up --build -d
```

## Demo with 1 replica per subset

```shell
# ssh into client side
docker exec -it demo_client-envoy_1 bash

# all traffic to local-1
python3 client.py http://localhost:3000/ 100

# bring down local-1
curl demo_backend-local-1_1:8000/unhealthy

# check healthiness
curl -s localhost:8001/clusters | grep health_flags

# local-2 and remote subset split the traffic 50:50
python3 client.py http://localhost:3000/ 100

# bring down local-2
curl demo_backend-local-2_1:8000/unhealthy

# remote subset receive 100% of the traffic
python3 client.py http://localhost:3000/ 100

# recover local-1 and local-2
curl demo_backend-local-1_1:8000/healthy
curl demo_backend-local-2_1:8000/healthy
```

**Conclusion:** when the highest priority locality is completely unhealthy, the remaining localities will share the traffic.

## Demo with multiple replicas per subset

Continue from previous steps. We first scale up the local-1 cluster

```shell
docker-compose -p demo scale backend-local-1=5
```

Run the remaining commands in demo_client-envoy_1 container.

```shell
# bring down local-1 replicas
curl demo_backend-local-1_2:8000/unhealthy
curl demo_backend-local-1_3:8000/unhealthy
curl demo_backend-local-1_4:8000/unhealthy
curl demo_backend-local-1_5:8000/unhealthy

# check healthiness
curl -s localhost:8001/clusters | grep health_flags

# watch traffic change
python3 client.py http://localhost:3000/ 100

# recover local-1 replicas
curl demo_backend-local-1_2:8000/healthy
curl demo_backend-local-1_3:8000/healthy
curl demo_backend-local-1_4:8000/healthy
curl demo_backend-local-1_5:8000/healthy
```

**Conclusion:** default overprovisioning factor is 1.4, which means, when the highest cluster has less than 71% of the workloads health, the LB will gradually shift traffic to other localities.