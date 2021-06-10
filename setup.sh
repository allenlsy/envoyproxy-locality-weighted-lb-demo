osm install --deploy-grafana --deploy-prometheus --enable-permissive-traffic-policy

# ./deploy-buyer.sh
# ./deploy-store-local-A.sh
# ./deploy-store-local-B.sh
# ./deploy-store-remote.sh
# ./deploy-warehouse.sh
echo "Create namespaces"

kubectl create namespace bookbuyer --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace bookwarehouse --dry-run=client -o yaml | kubectl apply -f -


echo "Create SAs"
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookbuyer
  namespace: bookbuyer
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
EOF

echo "Create bookbuyer"
kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookbuyer
  namespace: bookbuyer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookbuyer
      version: v1
  template:
    metadata:
      labels:
        app: bookbuyer
        version: v1
    spec:
      serviceAccountName: bookbuyer
      containers:
      - name: bookbuyer
        image: openservicemesh/bookbuyer:v0.8.4
        imagePullPolicy: Always
        command: ["/bookbuyer"]
        env:
        - name: "BOOKSTORE_NAMESPACE"
          value: bookstore
EOF


# boookstore
for bkns in bookstore-local-a bookstore-local-b bookstore-remote
do
    echo "Create $bkns"
    sa_name=$bkns
    kubectl create namespace $bkns --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $sa_name
  namespace: $bkns
---
apiVersion: v1
kind: Service
metadata:
  name: bookstore
  namespace: $bkns
  labels:
    app: bookstore
spec:
  selector:
    app: bookstore
  ports:
  - port: 14001
    name: bookstore-port
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookstore
  namespace: $bkns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookstore
  template:
    metadata:
      labels:
        app: bookstore
    spec:
      serviceAccountName: $sa_name
      containers:
      - name: bookstore
        image: openservicemesh/bookstore:v0.8.4
        imagePullPolicy: Always
        ports:
          - containerPort: 14001
        command: ["/bookstore"]
        args: ["--path", "./", "--port", "14001"]
        env:
        - name: BOOKWAREHOUSE_NAMESPACE
          value: bookwarehouse
        - name: IDENTITY
          value: bookstore-v1
EOF
osm namespace add $bkns
done

kubectl apply -f - <<EOF
kind: Service
apiVersion: v1
metadata:
  name: bookstore
  namespace: bookbuyer
spec:
  type: ExternalName
  externalName: bookstore-local-a.bookstore-local-a
  ports:
  - port: 80
EOF

# END boookstore

echo "Create bookwarehouse"
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
  labels:
    app: bookwarehouse
spec:
  selector:
    app: bookwarehouse
  ports:
  - port: 14001
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookwarehouse
  template:
    metadata:
      labels:
        app: bookwarehouse
        version: v1
    spec:
      serviceAccountName: bookwarehouse
      containers:
      - name: bookwarehouse
        image: openservicemesh/bookwarehouse:v0.8.4
        imagePullPolicy: Always
        command: ["/bookwarehouse"]
EOF

osm namespace add bookbuyer
osm namespace add bookwarehouse