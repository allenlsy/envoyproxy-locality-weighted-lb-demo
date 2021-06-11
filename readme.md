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
```

Now we see traffic splits between local-2 and remote subsets.

![Screen Shot 2021-06-11 at 4 00 14 PM](https://user-images.githubusercontent.com/872876/121756933-c0b49300-cad0-11eb-9596-11fc49aa3190.png)


```
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

Continue from previous steps. We first scale up the local-1 cluster to 5 replicas.

```shell
docker-compose -p demo scale backend-local-1=5
```

Run the remaining commands in demo_client-envoy_1 container. We are going to bring down some replicas in subset local-1.

```shell
# bring down local-1 replicas
curl demo_backend-local-1_2:8000/unhealthy
curl demo_backend-local-1_3:8000/unhealthy
curl demo_backend-local-1_4:8000/unhealthy
curl demo_backend-local-1_5:8000/unhealthy

# check healthiness
curl -s localhost:8001/clusters | grep health_flags
```

You should see something like this:

![Screen Shot 2021-06-11 at 4 10 31 PM](https://user-images.githubusercontent.com/872876/121756873-7a5f3400-cad0-11eb-8efb-00f2434b4234.png)

```shell
# watch traffic change
python3 client.py http://localhost:3000/ 100

# recover local-1 replicas
curl demo_backend-local-1_2:8000/healthy
curl demo_backend-local-1_3:8000/healthy
curl demo_backend-local-1_4:8000/healthy
curl demo_backend-local-1_5:8000/healthy
```

Cluster status after 


Output when only 1 replica is available in local-1:

![Screen Shot 2021-06-11 at 4 11 18 PM](https://user-images.githubusercontent.com/872876/121756890-8a771380-cad0-11eb-81dc-63e98259f3ea.png)


Output when 2 replicas is available in local-1:

![Screen Shot 2021-06-11 at 4 11 40 PM](https://user-images.githubusercontent.com/872876/121756898-94007b80-cad0-11eb-9613-dab818ef6b1e.png)


Output when 4 replica is available in local-1:

![Screen Shot 2021-06-11 at 4 15 30 PM](https://user-images.githubusercontent.com/872876/121756905-98c52f80-cad0-11eb-8e89-b04251cfa727.png)


**Conclusion:** default overprovisioning factor is 1.4, which means, when the highest cluster has less than 71% of the workloads health, the LB will gradually shift traffic to other localities.
