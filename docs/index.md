---
layout: default
title: RHBK + Data Grid — High Availability
description: Helm chart for Red Hat Build of Keycloak (RHBK) HA with Red Hat Data Grid and PostgreSQL
---

# RHBK + Data Grid — High Availability

Helm chart for **Red Hat Build of Keycloak (RHBK)** in High Availability mode with **Red Hat Data Grid** as external distributed cache and **PostgreSQL** as the shared database.

## Add the Helm Repository

```bash
helm repo add rhbk-datagrid https://maximilianopizarro.github.io/rhbk-datagrid-sample/
helm repo update
```

## Install

```bash
helm install ha rhbk-datagrid/rhbk-datagrid \
  -n keycloak-ha --create-namespace \
  --set admin.password=changeme \
  --set datagrid.credentials.password=s3cret \
  --set postgresql.credentials.password=dbpass
```

---

## OpenShift Topology

![OpenShift Topology View](datagrid-keycloak-topology.png)

---

## Architecture

```
┌──────────────────────────────────┐
│         PostgreSQL               │
│  Shared DB + JDBC_PING discovery │
└───────────────┬──────────────────┘
                │
        ┌───────┴───────┐
        │               │
   ┌────┴────┐   ┌──────┴──┐       ┌────────────────────────────┐
   │ RHBK-1  │   │ RHBK-2  │──────►│  Red Hat Data Grid (x2)    │
   │         │◄─►│         │       │  External distributed      │
   │ JGroups │   │ JGroups │       │  cache (Hot Rod: 11222)     │
   └─────────┘   └─────────┘       └────────────────────────────┘
        JGroups cluster
        (jdbc-ping via PostgreSQL)
```

### Components

| Component | Role |
|-----------|------|
| **RHBK (x2)** | Two Keycloak instances clustered via **JGroups** using the `jdbc-ping` stack. The `multi-site` feature enables connection to an external Data Grid for distributed session caching. |
| **Data Grid (x2)** | Two Infinispan server instances forming their own cluster via **JGroups DNS_PING**. They provide a remote distributed cache for Keycloak sessions. |
| **PostgreSQL (x1)** | Single-instance database storing Keycloak data. Also serves as the registry for JGroups `JDBC_PING2` node discovery. |

### JGroups Cluster Communication

- **RHBK cluster**: Uses `jdbc-ping` (default in RHBK 26.x). Nodes register in PostgreSQL and discover each other via database queries. Data transmission on TCP port **7800** with auto-generated mTLS certificates.
- **Data Grid cluster**: Uses `kubernetes` stack with `DNS_PING`. A headless Service resolves all Data Grid pod IPs for node discovery.

### Cache Architecture

| Cache | Type | Storage |
|-------|------|---------|
| `realms`, `users`, `authorization`, `keys` | Local | In-memory per RHBK node |
| `work` | Replicated | All RHBK nodes (invalidation) |
| `sessions`, `clientSessions` | Distributed | Embedded + remote Data Grid |
| `offlineSessions`, `offlineClientSessions` | Distributed | Embedded + remote Data Grid |
| `authenticationSessions`, `loginFailures`, `actionTokens` | Distributed | Embedded + remote Data Grid |

---

## Prerequisites

- **OpenShift** 4.x / Kubernetes 1.25+
- **Helm** 3.x
- **Red Hat registry access** (`podman login registry.redhat.io`) — or use community images

---

## Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n keycloak-ha

# Verify RHBK cluster formation (look for 2 nodes)
kubectl logs -l app.kubernetes.io/component=keycloak -n keycloak-ha | grep ISPN000094

# Access routes
kubectl get routes -n keycloak-ha
```

---

## Using Community Images

If you don't have access to `registry.redhat.io`:

```bash
helm install ha rhbk-datagrid/rhbk-datagrid \
  -n keycloak-ha --create-namespace \
  --set rhbk.image.repository=quay.io/keycloak/keycloak \
  --set rhbk.image.tag=26.0 \
  --set datagrid.image.repository=quay.io/infinispan/server \
  --set datagrid.image.tag=15.0 \
  --set postgresql.image.repository=docker.io/library/postgres \
  --set postgresql.image.tag=16-alpine
```

---

## Helm Chart Values

### RHBK

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rhbk.image.repository` | RHBK container image | `registry.redhat.io/rhbk/keycloak-rhel9` |
| `rhbk.image.tag` | Image tag | `26.0` |
| `rhbk.replicas` | Number of RHBK instances | `2` |
| `rhbk.resources.requests.cpu` | CPU request | `500m` |
| `rhbk.resources.requests.memory` | Memory request | `512Mi` |
| `rhbk.resources.limits.cpu` | CPU limit | `1` |
| `rhbk.resources.limits.memory` | Memory limit | `1Gi` |
| `rhbk.cache.stack` | JGroups transport stack | `jdbc-ping` |
| `rhbk.cache.remoteStore.enabled` | Connect to external Data Grid | `true` |
| `rhbk.cache.remoteStore.tlsEnabled` | TLS for Data Grid connection | `false` |
| `admin.username` | Admin username | `admin` |
| `admin.password` | Admin password | `admin` |

### Data Grid

| Parameter | Description | Default |
|-----------|-------------|---------|
| `datagrid.enabled` | Deploy Data Grid | `true` |
| `datagrid.image.repository` | Data Grid image | `registry.redhat.io/datagrid/datagrid-8-rhel9` |
| `datagrid.image.tag` | Image tag | `latest` |
| `datagrid.replicas` | Number of instances | `2` |
| `datagrid.clusterName` | JGroups cluster name | `datagrid-cluster` |
| `datagrid.credentials.username` | Hot Rod username | `developer` |
| `datagrid.credentials.password` | Hot Rod password | `changeme` |
| `datagrid.resources.requests.cpu` | CPU request | `250m` |
| `datagrid.resources.requests.memory` | Memory request | `512Mi` |
| `datagrid.route.enabled` | Create console Route | `true` |
| `datagrid.persistence.enabled` | Enable persistent storage | `false` |

### PostgreSQL

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `postgresql.image.repository` | PostgreSQL image | `registry.redhat.io/rhel9/postgresql-16` |
| `postgresql.credentials.database` | Database name | `keycloak` |
| `postgresql.credentials.username` | Database username | `keycloak` |
| `postgresql.credentials.password` | Database password | `changeme` |
| `postgresql.resources.requests.cpu` | CPU request | `250m` |
| `postgresql.resources.requests.memory` | Memory request | `256Mi` |

### Routes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `route.enabled` | RHBK Route | `true` |
| `route.tls.termination` | TLS termination | `edge` |
| `datagrid.route.enabled` | Data Grid console Route | `true` |

---

## Minimum Resources

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|------------|----------------|-----------|--------------|
| RHBK | 500m | 512Mi | 1 | 1Gi |
| Data Grid | 250m | 512Mi | 500m | 1Gi |
| PostgreSQL | 250m | 256Mi | 500m | 512Mi |
| **Total** | **1.75** | **2.25Gi** | **3** | **4.5Gi** |

---

## References

- [RHBK High Availability Guide](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.4/html/high_availability_guide/)
- [RHBK Configuring Distributed Caches](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/26.4/html/server_configuration_guide/caching-)
- [Connect RHBK with External Data Grid](https://docs.redhat.com/en/documentation/red_hat_build_of_keycloak/24.0/html/high_availability_guide/connect-keycloak-to-external-infinispan-)
- [Data Grid Helm Chart Configuration](https://docs.redhat.com/en/documentation/red_hat_data_grid/8.4/html/building_and_deploying_data_grid_clusters_with_helm/configuring-servers)
- [Source Code](https://github.com/maximilianoPizarro/rhbk-datagrid-sample)
