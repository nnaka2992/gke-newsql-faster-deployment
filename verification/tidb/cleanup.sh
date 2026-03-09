#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleaning up TiDB ==="

# Delete TiDB cluster resources
kubectl delete tc basic -n tidb-cluster 2>/dev/null || true
kubectl delete tidbmonitor basic -n tidb-cluster 2>/dev/null || true
kubectl delete pvc -l app.kubernetes.io/instance=basic,app.kubernetes.io/managed-by=tidb-operator -n tidb-cluster 2>/dev/null || true

# Delete TiDB cluster namespace
kubectl delete namespace tidb-cluster --wait=false 2>/dev/null || true

# Uninstall TiDB Operator
helm uninstall tidb-operator -n tidb-admin --no-hooks 2>/dev/null || true

# Delete TiDB Operator namespace
kubectl delete namespace tidb-admin --wait=false 2>/dev/null || true

# Delete TiDB CRDs
kubectl delete crd -l app.kubernetes.io/managed-by=tidb-operator 2>/dev/null || true
kubectl get crds -o name | grep pingcap.com | xargs kubectl delete 2>/dev/null || true

# Force-remove stuck namespaces
for ns in tidb-cluster tidb-admin; do
  if kubectl get namespace "$ns" &>/dev/null; then
    echo "Namespace $ns stuck in Terminating, removing finalizer..."
    kubectl get namespace "$ns" -o json \
      | jq '.spec.finalizers = []' \
      | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
  fi
done

echo "=== TiDB cleanup done ==="
