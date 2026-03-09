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
rm -rf ./helm-charts
rm -f client-secure.yaml
START_TIME=$SECONDS

# 1. Get Google Account Mail Address
echo "=== 1. Get Google Account Mail Address"
email=$(gcloud info --format json | jq ".config.account")
((++steps))

# 2. Create RBAC
echo "=== 2. Create RBAC"
kubectl create clusterrolebinding $USER-cluster-admin-binding \
  --clusterrole=cluster-admin\
  --user=$email
((++steps))

# 3. Clone Git Repos
echo "=== 3. Clone Git Repos"
git clone https://github.com/cockroachdb/helm-charts.git
((++steps))

# 4. Update values.
echo "=== 4. Clone Git Repos"
cp values.yaml helm-charts/cockroachdb-parent/charts/cockroachdb/values.yaml
((++steps))

# 5. export env variables
echo "=== 5. export env variables"
export CRDBOPERATOR=crdb-operator
export CRDBCLUSTER=cockroachdb
export NAMESPACE=cockroach-ns
((++steps))

# 6. Create namesapce
echo "=== 6. Create namesapce"
kubectl create namespace $NAMESPACE; ((++steps))

# 7. helm install operator
echo "=== 7. helm install operator"
echo "Penalty. Script on document is not performing cd."
cd ./helm-charts
helm install $CRDBOPERATOR \
  ./cockroachdb-parent/charts/operator\
  -n $NAMESPACE
((++steps))
((++penalty))

# 8. helm install database
echo "=== 8. helm install database"
echo "Penalty, document said cockroachdb.crdbCluster.podTemplate.spec.resources but it is actually cockroachdb.crdbCluster.podTemplate.spec.container.resources"

helm install $CRDBCLUSTER \
  ./cockroachdb-parent/charts/cockroachdb \
  -n $NAMESPACE
((++steps))

cd $script_dir

# Wait for CockroachDB pods to be ready
echo "=== Waiting for CockroachDB cluster to be ready..."
until kubectl get pods -l app.kubernetes.io/name=cockroachdb -n $NAMESPACE 2>/dev/null | grep -q cockroachdb; do
  echo "Waiting for CockroachDB pods to be created..."
  sleep 1
done
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=cockroachdb -n $NAMESPACE --timeout=300s

# 9. Download the secure client Kubernetes application definition
echo "=== 9. Download the secure client Kubernetes application definition"
curl -O https://raw.githubusercontent.com/cockroachdb/helm-charts/master/examples/client-secure.yaml
((++steps))

# 10. Fix image version in client-secure.yaml
echo "=== 10. Fix image version in client-secure.yaml"
sed -i 's|cockroachdb/cockroach:v21.1.11|cockroachdb/cockroach:v26.1.0|' client-secure.yaml
((++steps))

# 11. Create secure client Kubernetes application
echo "=== 11. Create secure client Kubernetes application"
echo "Penalty, namespace does not specify on document"
kubectl create -f client-secure.yaml -n $NAMESPACE
((++steps))
((++penalty))

# 12. Execute SQL
echo "=== 12. Execute SQL"
echo "Penalty, namespace does not specify on document"
kubectl wait --for=condition=Ready pod/cockroachdb-client-secure -n $NAMESPACE --timeout=120s
kubectl exec -it cockroachdb-client-secure -n $NAMESPACE \
-- ./cockroach sql --execute="SELECT 'Hello, CockroachDB';" \
--certs-dir=/cockroach/cockroach-certs \
--host=cockroachdb-public
((++steps))
((++penalty))

# Result
elapsed_time=$(($SECONDS - $START_TIME))

echo "=== RESULT(CockroachDB)"
echo "steps   $steps"
echo "penalty $penalty"
echo "time    $elapsed_time"
