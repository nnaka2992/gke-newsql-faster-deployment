#!/usr/bin/env bash
set -euo pipefail

#######################################################################
# GKE cluster setup script for NewSQL benchmarking
#
# Creates a GKE cluster sized to max(DB minimum requirements):
#   - CockroachDB: 2 vCPU + 8Gi per pod x 3 pods (most demanding)
#   - TiDB: PD + TiKV + TiDB (basic)
#   - YugabyteDB: master + tserver (quickstart)
#
# Node type: e2-standard-4 (4 vCPU, 16GB) x 3 nodes
#   => 12 vCPU, 48GB total (sufficient for all three DBs)
#######################################################################

# All env vars are set via .mise.toml / .mise.local.toml
# Required: GCP_PROJECT_ID, GKE_CLUSTER_NAME, GKE_REGION, GKE_MACHINE_TYPE, GKE_NUM_NODES, GKE_DISK_SIZE

echo "=== GKE NewSQL Benchmark Cluster Setup ==="
echo "Project:      ${GCP_PROJECT_ID}"
echo "Cluster:      ${GKE_CLUSTER_NAME}"
echo "Region:       ${GKE_REGION}"
echo "Machine type: ${GKE_MACHINE_TYPE}"
echo "Nodes/zone:   ${GKE_NUM_NODES}"
echo "Disk size:    ${GKE_DISK_SIZE}GB"
echo ""

# Set project
gcloud config set project "${GCP_PROJECT_ID}"

# Enable required APIs
echo "--- Enabling required APIs ---"
gcloud services enable container.googleapis.com

# Create regional GKE cluster
echo "--- Creating regional GKE cluster ---"
gcloud container clusters create "${GKE_CLUSTER_NAME}" \
  --region "${GKE_REGION}" \
  --machine-type "${GKE_MACHINE_TYPE}" \
  --num-nodes "${GKE_NUM_NODES}" \
  --disk-size "${GKE_DISK_SIZE}" \
  --disk-type pd-ssd \
  --no-enable-autoupgrade \
  --release-channel None

# Get credentials
echo "--- Fetching cluster credentials ---"
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" \
  --region "${GKE_REGION}"

# Verify
echo "--- Verifying cluster ---"
kubectl cluster-info
kubectl get nodes

echo ""
echo "=== GKE cluster '${GKE_CLUSTER_NAME}' is ready ==="
