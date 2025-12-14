#!/bin/bash
# Script to generate Cilium manifest using Helm with optimized values for Talos
# This generates a manifest that uses Cilium LoadBalancer IPAM instead of MetalLB

set -e

CILIUM_VERSION="${CILIUM_VERSION:-1.18.4}"
OUTPUT_FILE="${OUTPUT_FILE:-${PWD}/manifests/cilium-cni-${CILIUM_VERSION}.yaml}"
POD_CIDR="${POD_CIDR:-10.244.0.0/16}"
SERVICE_CIDR="${SERVICE_CIDR:-10.96.0.0/12}"

# Ensure helm repo is added
if ! helm repo list | grep -q cilium; then
  echo "Adding Cilium Helm repository..."
  helm repo add cilium https://helm.cilium.io/
fi

echo "Updating Helm repositories..."
helm repo update

echo "Generating Cilium manifest with version ${CILIUM_VERSION}..."
echo "Output file: ${OUTPUT_FILE}"

# Generate Cilium manifest with optimized values for Talos
helm template \
  cilium \
  cilium/cilium \
  --version "${CILIUM_VERSION}" \
  --namespace cilium \
  --set ipam.mode=kubernetes \
  --set kubeProxyReplacement=true \
  --set ipv4NativeRoutingCIDR="${POD_CIDR}" \
  --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  --set cgroup.autoMount.enabled=false \
  --set cgroup.hostRoot=/sys/fs/cgroup \
  --set k8sServiceHost=localhost \
  --set k8sServicePort=7445 \
  --set gatewayAPI.enabled=true \
  --set gatewayAPI.enableAlpn=true \
  --set gatewayAPI.enableAppProtocol=true \
  --set l2announcements.enabled=true \
  --set defaultLBServiceIPAM=lbipam \
  --set lbExternalClusterIP=true \
  --set hubble.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  > "${OUTPUT_FILE}"

  # --set gatewayAPI.enabled=true \
  # --set kubeProxyReplacement=strict \
  # --set ipam.mode=kubernetes \
  # --set ipv4NativeRoutingCIDR="${POD_CIDR}" \
  # --set kubeProxyReplacement=true \
  # --set routingMode=native \
  # --set loadBalancer.mode=dsr \
  # --set loadBalancer.algorithm=maglev \
  # --set bgpControlPlane.enabled=true \
  # --set l2announcements.enabled=true \
  # --set defaultLBServiceIPAM=lbipam \
  # --set lbExternalClusterIP=true \
  # --set rollOutCiliumPods=true \
  # --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
  # --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
  # --set cgroup.autoMount.enabled=false \
  # --set cgroup.hostRoot=/sys/fs/cgroup \
  # --set k8sServiceHost=localhost \
  # --set k8sServicePort=7445 \
  # --set hubble.enabled=true \
  # --set hubble.relay.enabled=true \
  # --set hubble.ui.enabled=true \

echo "Cilium manifest generated successfully at ${OUTPUT_FILE}"
echo ""
echo "Next steps:"
echo "1. Review the generated manifest"
echo "2. Create a CiliumLoadBalancerIPPool resource for LoadBalancer IP allocation"
echo "3. Update Talos configuration to use this manifest instead of the external URL"

