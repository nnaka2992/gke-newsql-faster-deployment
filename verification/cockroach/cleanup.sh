#!/usr/bin/env bash
set -euo pipefail

echo "=== Cleaning up CockroachDB ==="

# Delete client-secure pod
kubectl delete pod cockroachdb-client-secure -n cockroach-ns --grace-period=0 --force 2>/dev/null || true

# Uninstall helm releases (cockroachdb first, then operator)
helm uninstall cockroachdb -n cockroach-ns --wait 2>/dev/null || true
helm uninstall crdb-operator -n cockroach-ns --wait 2>/dev/null || true

# Delete any remaining pods force
kubectl delete pods --all -n cockroach-ns --grace-period=0 --force 2>/dev/null || true

# Delete PVCs
kubectl delete pvc --all -n cockroach-ns --grace-period=0 --force 2>/dev/null || true

# Delete webhook configurations (prevents namespace stuck in Terminating)
kubectl delete validatingwebhookconfiguration cockroach-webhook-config 2>/dev/null || true
kubectl delete mutatingwebhookconfiguration cockroach-mutating-webhook-config 2>/dev/null || true

# Delete CRDs
kubectl delete crd \
  crdbclusters.crdb.cockroachlabs.com \
  crdbnodes.crdb.cockroachlabs.com \
  crdbtenants.crdb.cockroachlabs.com \
  2>/dev/null || true

# Delete namespace, force-remove finalizer if stuck
kubectl delete namespace cockroach-ns --wait=false 2>/dev/null || true
if kubectl get namespace cockroach-ns &>/dev/null; then
  echo "Namespace stuck in Terminating, removing finalizer..."
  kubectl get namespace cockroach-ns -o json \
    | jq '.spec.finalizers = []' \
    | kubectl replace --raw "/api/v1/namespaces/cockroach-ns/finalize" -f - 2>/dev/null || true
fi

# Delete clusterrolebinding
kubectl delete clusterrolebinding "${USER}-cluster-admin-binding" 2>/dev/null || true

echo "=== CockroachDB cleanup done ==="
