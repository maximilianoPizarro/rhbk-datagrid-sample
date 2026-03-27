# RHBK + Data Grid HA — Architecture

## Deployment Topology

```
                    ┌─────────────────────────────────┐
                    │          OpenShift Route         │
                    │     (TLS edge termination)       │
                    └────────────────┬────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │        RHBK Service             │
                    │    (ClusterIP - load balance)    │
                    └────────┬───────────┬────────────┘
                             │           │
                    ┌────────┴──┐   ┌────┴───────┐
                    │  RHBK-1   │   │  RHBK-2    │
                    │           │   │            │
                    │  Port     │   │  Port      │
                    │  8080 HTTP│   │  8080 HTTP │
                    │  8443 TLS │   │  8443 TLS  │
                    │  9000 Mgmt│   │  9000 Mgmt │
                    │  7800 JGrp│◄─►│  7800 JGrp │
                    │           │   │            │
                    └──┬──┬─────┘   └────┬──┬────┘
                       │  │              │  │
          ┌────────────┘  └──────┬───────┘  └──────────┐
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   PostgreSQL    │   │  Data Grid -0    │   │  Data Grid -1    │
│                 │   │                  │   │                  │
│  Port 5432     │   │  Port 11222      │   │  Port 11222      │
│                 │   │  (Hot Rod/REST)  │   │  (Hot Rod/REST)  │
│  • RHBK data   │   │  Port 7800       │◄─►│  Port 7800       │
│  • JDBC_PING   │   │  (JGroups)       │   │  (JGroups)       │
│    discovery   │   │                  │   │                  │
└─────────────────┘   └──────────────────┘   └──────────────────┘
```

## Communication Flows

### 1. JGroups — RHBK Cluster Formation (jdbc-ping)

```
RHBK-1                    PostgreSQL                   RHBK-2
  │                          │                           │
  │─── INSERT node info ────►│                           │
  │                          │◄─── INSERT node info ─────│
  │                          │                           │
  │─── SELECT all nodes ───►│                           │
  │◄── [RHBK-1, RHBK-2] ───│                           │
  │                          │                           │
  │◄═══════ TCP 7800 ══════════════════════════════════►│
  │    JGroups data          │    (mTLS auto-generated   │
  │    transmission          │     certs stored in DB)   │
  │                          │                           │
  │◄═══════ TCP 57800 ═════════════════════════════════►│
  │    FD_SOCK2 failure      │                           │
  │    detection             │                           │
```

### 2. JGroups — Data Grid Cluster Formation (DNS_PING)

```
DG-0                 Headless Service DNS           DG-1
  │                        │                          │
  │── DNS query ──────────►│                          │
  │◄─ [DG-0 IP, DG-1 IP]──│                          │
  │                        │                          │
  │◄══════ TCP 7800 ═════════════════════════════════►│
  │   JGroups data         │                          │
  │   transmission         │                          │
```

### 3. RHBK → Data Grid (Hot Rod remote store)

```
RHBK-1/2                              Data Grid Service
  │                                        │
  │── Hot Rod (TCP 11222) ────────────────►│
  │   • Create/read/update sessions        │
  │   • Auth: username/password            │
  │   • TLS: configurable                  │
  │                                        │
  │◄── Session data ──────────────────────│
```

## Kubernetes Services

| Service | Type | Purpose |
|---------|------|---------|
| `*-rhbk` | ClusterIP | RHBK HTTP/HTTPS load balancing |
| `*-datagrid` | ClusterIP | Data Grid Hot Rod client connections |
| `*-datagrid-headless` | Headless | Data Grid JGroups DNS_PING discovery |
| `*-postgresql` | ClusterIP | PostgreSQL database connections |

## Network Ports

| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| RHBK | 8080 | HTTP | Web UI and REST API |
| RHBK | 8443 | HTTPS | Secure web access |
| RHBK | 9000 | HTTP | Health/metrics management |
| RHBK | 7800 | TCP | JGroups cluster data |
| RHBK | 57800 | TCP | JGroups failure detection (FD_SOCK2) |
| Data Grid | 11222 | TCP | Hot Rod + REST endpoints |
| Data Grid | 7800 | TCP | JGroups cluster data |
| PostgreSQL | 5432 | TCP | Database connections |
