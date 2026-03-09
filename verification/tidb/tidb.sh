# 0. setups
set -euo pipefail

script_dir=$(dirname "$(realpath $0)")
current_dir=$PWD
steps=0
penalty=0

cleanup() {
  cd $current_dir;
}

trap cleanup EXIT
cd $script_dir
START_TIME=$SECONDS

# 1. Install TiDB Operator CRDs
echo "=== 1. Install TiDB Operator CRDs"
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.5/manifests/crd.yaml
((++steps))

# 2. Add PingCAP Helm repository
echo "=== 2. Add PingCAP Helm repository"
helm repo add pingcap https://charts.pingcap.com/
((++steps))

# 3. Create TiDB Operator namespace
echo "=== 3. Create TiDB Operator namespace"
kubectl create namespace tidb-admin
((++steps))

# 4. Install TiDB Operator
echo "=== 4. Install TiDB Operator"
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.6.5
((++steps))

# Wait for TiDB Operator to be ready
echo "=== Waiting for TiDB Operator to be ready..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/instance=tidb-operator -n tidb-admin --timeout=300s

# 5. Create TiDB Cluster namespace and deploy cluster
echo "=== 5. Create TiDB Cluster namespace and deploy cluster"
kubectl create namespace tidb-cluster &&\
kubectl -n tidb-cluster apply -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.5/examples/basic/tidb-cluster.yaml
((++steps))

# Wait for TiDB cluster pods to be ready
echo "=== Waiting for TiDB cluster to be ready..."
until kubectl get pods -l app.kubernetes.io/instance=basic -n tidb-cluster 2>/dev/null | grep -q basic; do
  echo "Waiting for TiDB pods to be created..."
  sleep 1
done
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/instance=basic -n tidb-cluster --timeout=600s

# Wait for basic-tidb pod and service to be available
echo "=== Waiting for basic-tidb pod to be ready..."
until kubectl get pods -l app.kubernetes.io/component=tidb -n tidb-cluster 2>/dev/null | grep -q basic-tidb; do
  sleep 1
done
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/component=tidb -n tidb-cluster --timeout=600s

# 6. Get service name
echo "=== 6. Get service name"
svc=$(kubectl get svc -n tidb-cluster -oname | grep "basic-tidb$" | sed 's|service/||' )
((++steps))

# 7. set up Port-forward
kubectl port-forward -n tidb-cluster svc/$svc 14000:4000 > pf14000.out &
PF_PID=$!
((++steps))

# Wait for port-forward to be ready
until mysqladmin ping -h 127.0.0.1 -P 14000 -u root --silent 2>/dev/null; do
  sleep 1
done

# 8. Execute SQL
echo "=== 8. Execute SQL"
mysql --comments -h 127.0.0.1 -P 14000 -u root -e "SELECT 'Hello, TiDB';"
((++steps))

# Result
elapsed_time=$(($SECONDS - $START_TIME))

echo "=== RESULT(TiDB)"
echo "steps   $steps"
echo "penalty $penalty"
echo "time    $elapsed_time"
