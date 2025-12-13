# homelab-talos-cni

This project generates a Cilium CNI manifest optimized for Talos Linux using Helm. The generated manifest replaces the default Cilium configuration with settings specifically tailored for Talos's unique requirements, including native routing, kube-proxy replacement, and LoadBalancer IPAM.

## Overview

Cilium is a CNI (Container Network Interface) plugin that provides networking, security, and observability for Kubernetes clusters. When deploying Cilium on Talos Linux, certain configuration parameters must be adjusted to work correctly with Talos's immutable, container-optimized architecture.

## Prerequisites

- Helm 3.x installed
- Access to the Cilium Helm repository
- Talos Linux cluster (or preparing to deploy one)

## Usage

Run the generation script:

```bash
./generate-cilium-manifest.sh
```

The script accepts the following environment variables:

- `CILIUM_VERSION`: Cilium version to use (default: `1.18.4`)
- `OUTPUT_FILE`: Output path for the generated manifest (default: `manifests/cilium-cni-${CILIUM_VERSION}.yaml`)
- `POD_CIDR`: Pod CIDR range (default: `10.244.0.0/16`)
- `SERVICE_CIDR`: Service CIDR range (default: `10.96.0.0/12`)

## Helm Chart Parameters Explained

The following parameters are set in the Helm chart to optimize Cilium for Talos Linux:

### Core Networking Configuration

#### `ipam.mode=kubernetes`

- **Purpose**: Configures Cilium to use Kubernetes-native IPAM (IP Address Management)
- **Why needed**: This mode allows Cilium to integrate directly with Kubernetes's IP allocation mechanisms, ensuring proper pod IP assignment and management within the cluster

#### `kubeProxyReplacement=true`

- **Purpose**: Enables Cilium's kube-proxy replacement feature
- **Why needed**: Cilium can replace kube-proxy entirely, providing better performance and observability. This eliminates the need for a separate kube-proxy daemon and reduces resource overhead

#### `ipv4NativeRoutingCIDR="${POD_CIDR}"`

- **Purpose**: Defines the CIDR range for native routing mode
- **Why needed**: Tells Cilium which IP range to use for direct routing, bypassing encapsulation overhead. This improves network performance by using the host network stack directly for pod-to-pod communication

### Security Context Configuration

#### `securityContext.capabilities.ciliumAgent`

- **Purpose**: Defines Linux capabilities required by the Cilium agent
- **Why needed**: Cilium needs specific capabilities to manage network interfaces, routing tables, and BPF programs. These capabilities include:

  - `CHOWN`, `FOWNER`, `SETGID`, `SETUID`: File ownership management
  - `KILL`: Process management
  - `NET_ADMIN`, `NET_RAW`: Network interface and packet manipulation
  - `IPC_LOCK`: Shared memory locking for BPF maps
  - `SYS_ADMIN`, `SYS_RESOURCE`: System administration and resource limits
  - `DAC_OVERRIDE`: Override file access permissions

#### `securityContext.capabilities.cleanCiliumState`

- **Purpose**: Defines capabilities for the Cilium state cleanup job
- **Why needed**: The cleanup job requires elevated privileges to remove BPF programs and network interfaces during uninstallation or upgrades

### Cgroup Configuration

#### `cgroup.autoMount.enabled=false`

- **Purpose**: Disables automatic cgroup mounting
- **Why needed**: Talos Linux manages cgroups at the system level. Disabling auto-mount prevents conflicts with Talos's cgroup management

#### `cgroup.hostRoot=/sys/fs/cgroup`

- **Purpose**: Sets the host cgroup root path
- **Why needed**: Points Cilium to the correct cgroup filesystem location on Talos, which uses a specific cgroup hierarchy structure

### Kubernetes API Server Configuration

#### `k8sServiceHost=localhost`

- **Purpose**: Sets the Kubernetes API server hostname
- **Why needed**: Talos runs the Kubernetes API server as a local service. Using `localhost` ensures Cilium can communicate with the API server without network routing issues

#### `k8sServicePort=7445`

- **Purpose**: Sets the Kubernetes API server port
- **Why needed**: Talos uses a non-standard port (7445) for the local Kubernetes API server instead of the default 6443. This ensures Cilium connects to the correct endpoint

### Gateway API Configuration

#### `gatewayAPI.enabled=true`

- **Purpose**: Enables Kubernetes Gateway API support
- **Why needed**: Provides support for the modern Gateway API specification, allowing for more flexible and powerful ingress configurations

#### `gatewayAPI.enableAlpn=true`

- **Purpose**: Enables ALPN (Application-Layer Protocol Negotiation) support
- **Why needed**: Allows Gateway API to negotiate protocols like HTTP/2 and gRPC at the application layer, improving performance and compatibility

#### `gatewayAPI.enableAppProtocol=true`

- **Purpose**: Enables application protocol support
- **Why needed**: Allows Gateway API to understand and route application-specific protocols beyond HTTP/HTTPS

### LoadBalancer Configuration

#### `l2announcements.enabled=true`

- **Purpose**: Enables Layer 2 announcements for LoadBalancer services
- **Why needed**: Allows Cilium to announce LoadBalancer IPs using ARP/NDP, making services accessible on the local network without requiring external load balancers

#### `defaultLBServiceIPAM=lbipam`

- **Purpose**: Sets the default IPAM mode for LoadBalancer services
- **Why needed**: Configures Cilium to use its built-in LoadBalancer IPAM (LBIPAM) instead of external solutions like MetalLB. This provides native LoadBalancer support without additional components

#### `lbExternalClusterIP=true`

- **Purpose**: Enables external ClusterIP allocation for LoadBalancer services
- **Why needed**: Allows LoadBalancer services to use IPs from external pools, providing more flexibility in IP allocation and management

## Generated Manifest

The generated manifest is saved to `manifests/cilium-cni-${VERSION}.yaml` and includes all necessary Kubernetes resources:

- Namespace
- ServiceAccounts
- ClusterRoles and ClusterRoleBindings
- ConfigMaps
- DaemonSets
- Deployments
- Services
- Custom Resource Definitions (CRDs)

## Post-Deployment Steps

After generating the manifest:

1. **Review the generated manifest** to ensure all parameters are correctly set
2. **Create a CiliumLoadBalancerIPPool resource** to define the IP pool for LoadBalancer services:

   ```yaml
   # CiliumLoadBalancerIPPool defines a pool of IP addresses that Cilium LB IPAM
   # can allocate to LoadBalancer services.
   #
   # Usage:
   #   - Services without a loadBalancerClass will automatically get IPs from this pool
   #   - Services can specify loadBalancerClass: "io.cilium/l2-announcer" for L2 announcements
   #   - Services can specify loadBalancerClass: "io.cilium/bgp-control-plane" for BGP
   #
   apiVersion: "cilium.io/v2alpha1"
   kind: CiliumLoadBalancerIPPool
   metadata:
     name: default-ip-pool
     namespace: cilium
   spec:
     blocks:
       - cidr: 192.168.1.200/29
     serviceSelector:
       matchLabels: {}
     disabled: false
   ```

3. **Create a CiliumL2AnnouncementPolicy resource** to configure L2 announcements for LoadBalancer services:

   ```yaml
   # CiliumL2AnnouncementPolicy configures how Cilium announces LoadBalancer IPs
   # using ARP (IPv4) or NDP (IPv6) on the local network.
   #
   # This policy enables Layer 2 announcements so that LoadBalancer services
   # are accessible on the local network without requiring external load balancers.
   #
   apiVersion: "cilium.io/v2alpha1"
   kind: CiliumL2AnnouncementPolicy
   metadata:
     name: default-l2-announcement
     namespace: cilium
   spec:
     serviceSelector:
       matchLabels: {}
     nodeSelector:
       matchLabels: {}
     interfaces:
       - ^eth[0-9]+
     loadBalancerClass: "io.cilium/l2-announcer"
   ```

4. **Update Talos configuration** to use the local manifest instead of the external Cilium URL
5. **Apply the manifest** to your Talos cluster

## References

- [Cilium Documentation](https://docs.cilium.io/)
- [Talos Linux Documentation](https://www.talos.dev/)
- [Cilium Helm Chart Values](https://github.com/cilium/cilium/tree/main/install/kubernetes/cilium/values.yaml)
