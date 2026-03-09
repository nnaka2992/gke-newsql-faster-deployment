#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleaning up YugabyteDB ==="

# Uninstall helm release and wait for pods to terminate
helm uninstall yb-demo -n yb-demo --wait 2>/dev/null || true

# Force delete remaining pods
kubectl delete pods --all -n yb-demo --grace-period=0 --force 2>/dev/null || true

# Remove PVC finalizers and force delete
for pvc in $(kubectl get pvc -n yb-demo -o name 2>/dev/null); do
  kubectl patch "$pvc" -n yb-demo -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
done
kubectl delete pvc --all -n yb-demo --grace-period=0 --force 2>/dev/null || true

# Delete namespace
kubectl delete namespace yb-demo --wait=false 2>/dev/null || true

# Remove orphaned PVs
for pv in $(kubectl get pv -o name 2>/dev/null | grep yb); do
  kubectl patch "$pv" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
  kubectl delete "$pv" --grace-period=0 --force 2>/dev/null || true
done

# Force-remove stuck namespace
if kubectl get namespace yb-demo &>/dev/null; then
  echo "Namespace stuck in Terminating, removing finalizer..."
  kubectl get namespace yb-demo -o json \
    | jq '.spec.finalizers = []' \
    | kubectl replace --raw "/api/v1/namespaces/yb-demo/finalize" -f - 2>/dev/null || true
fi

echo "=== YugabyteDB cleanup done ==="
