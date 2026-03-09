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

# 1. Add YugabyteDB Helm repository
echo "=== 1. Add YugabyteDB Helm repository"
helm repo add yugabytedb https://charts.yugabyte.com
((++steps))

# 2. Fetch updates
echo "=== 2. Fetch updates"
helm repo update
((++steps))

# 3. Validate chart version
echo "=== 3. Validate chart version"
helm search repo yugabytedb/yugabyte --version 2025.2.1
((++steps))

# 4. Create namespace and install cluster
echo "=== 4. Create namespace and install cluster"
kubectl create namespace yb-demo
helm install yb-demo yugabytedb/yugabyte \
--version 2025.2.1 \
--set resource.master.requests.cpu=0.5,resource.master.requests.memory=0.5Gi,\
resource.tserver.requests.cpu=0.5,resource.tserver.requests.memory=0.5Gi,\
replicas.master=1,replicas.tserver=1 --namespace yb-demo
((++steps))

# Wait for YugabyteDB pods to be ready
echo "=== Waiting for YugabyteDB cluster to be ready..."
until kubectl get pods -n yb-demo 2>/dev/null | grep -q yb-tserver; do
  echo "Waiting for YugabyteDB pods to be created..."
  sleep 1
done
kubectl wait --for=condition=Ready pods -l app=yb-tserver -n yb-demo --timeout=600s

# 5. Check pod status
echo "=== 5. Check pod status"
kubectl --namespace yb-demo get pods
((++steps))

# Wait for YSQL to be ready
echo "=== Waiting for YSQL to accept connections..."
until kubectl --namespace yb-demo exec yb-tserver-0 -c yb-tserver -- sh -c "cd /home/yugabyte && ysqlsh -h yb-tserver-0 -c 'SELECT 1'" &>/dev/null; do
  sleep 1
done

# 6. Connect and execute SQL
echo "=== 6. Connect and execute SQL"
kubectl --namespace yb-demo exec -it yb-tserver-0 -c yb-tserver -- sh -c "cd /home/yugabyte && ysqlsh -h yb-tserver-0 -c \"SELECT 'Hello, YugabyteDB';\""
((++steps))

# Result
elapsed_time=$(($SECONDS - $START_TIME))

echo "=== RESULT(YugabyteDB)"
echo "steps   $steps"
echo "penalty $penalty"
echo "time    $elapsed_time"
