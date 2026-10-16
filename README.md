# NixOS Server Infrastructure

100% Infrastructure as Code (IaC) configuration for a headless server node managed via Nix Flakes. Features modular service orchestration, self-hosted mesh networking (Headscale), declarative reverse proxy routing, and GitOps-compliant secret management via SOPS.

## 1. Architecture Overview

This repository defines the complete operating state of a production home server node. Every daemon, routing rule, container runtime, and scheduled task is hermetically declared and version-controlled.

```
├── flake.nix                  # Flake entrypoint and dependency pinning
├── configuration.nix          # Base system invariants and core settings
├── hardware-configuration.nix # Target hardware profile and disk layout
├── secrets/                   # Declarative secret management
│   ├── sops.nix               # sops-nix integration and runtime symlink paths
│   └── secret.yaml            # SOPS-encrypted secrets (committed via age)
└── services/                  # Decoupled service modules
    ├── infrastructure.nix     # Core daemons, container runtimes, and system prerequisites
    ├── network.nix            # Routing, firewall, ingress reverse proxy, and Headscale mesh
    ├── backup.nix             # Automated persistence, verification, and scheduled snapshots
    ├── dashboard.nix          # Observability, status monitoring, and health metrics
    ├── media.nix              # Internal media streaming and ingestion services
    └── utilities.nix          # Scheduled maintenance tasks and background helpers
```

## 2. Core Operational System

### Declarative Infrastructure as Code (IaC)

- The entire server topology is reproducible from scratch with a single flake evaluation.
    
- Service units, firewall policies, storage mounts, and network namespaces are defined strictly in Nix—eliminating configuration drift and out-of-band manual interventions.
    

### Self-Hosted Mesh Network & Ingress Routing

- **Zero-Trust Private Mesh (Headscale):** Operates a self-hosted control plane for Tailscale, establishing point-to-point WireGuard tunnels between server nodes, mobile workstations, and remote clients without reliance on third-party SaaS infrastructure.
    
- **Declarative Reverse Proxy:** Ingress traffic is managed via a dedicated reverse proxy handling automatic TLS certificate lifecycle management, secure header enforcement, and internal DNS routing across services.
    

### Declarative Secret Management (`sops-nix`)

- Sensitive values (tokens, credentials, private WireGuard pre-shared keys) are encrypted at rest using **SOPS** (`secrets/secret.yaml`) via an `age` key.
    
- The repository can remain **fully public** without exposing authentication secrets.
    
- At runtime, `sops-nix` injects secrets into an in-memory `ramfs` (`/run/secrets/`), ensuring that sensitive values are never written to the immutable Nix store.
    

### Automated Backup & Persistence Lifecycle

- Scheduled snapshots and remote backups (`backup.nix`) run via systemd timers with automated validation of target endpoints and dataset integrity.
    

## 3. Deployment Workflow

Rebuilding or updating the server requires a Nix installation with flakes enabled.

### Local Deployment

```
# Apply configuration directly on the server node
sudo nixos-rebuild switch --flake .#server1
```

### Remote Deployment (Over SSH / Mesh Network)

```
# Build and activate remotely from a workstation
nixos-rebuild switch --flake .#server1 --target-host root@<server-ip-or-tailscale-node>
```

### Secret Editing

To edit encrypted secrets in place (requires the local `age` private key):

```
sops secrets/secret.yaml
```

## 4. Repository Hygiene

- **Zero Plaintext Secrets:** All sensitive credentials are verified against `sops.nix` and encrypted via SOPS before commit.
    
- **Reproducibility:** Upstream channels (`nixpkgs`) and third-party tools are pinned via `flake.lock`.