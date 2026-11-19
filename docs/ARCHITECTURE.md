# Architecture

## Components
| Component | Kind | Image / Port | Purpose |
|---|---|---|---|
| `catalog-deployment` | Deployment | `catalog:v1`, container port 5000 | Backend product API; 1 replica initially, scaled to 3 |
| `catalog-service` | Service (ClusterIP) | port 5000 → 5000 | Stable DNS name/IP for catalog Pods (selector `app: catalog`) |
| `frontend-deployment` | Deployment | `frontend:v1`, container port 5000 | Web frontend; calls `catalog-service` |
| `frontend-service` | Service (ClusterIP) | port 80 → 5000 | Stable address for frontend Pod; reached via `kubectl port-forward` |

## Cluster (Kind, name `microservices-lab`)
- 1 control-plane node (tainted – normal Pods are not scheduled there)
- 2 worker nodes (application Pods are scheduled here)

## Request flow
1. Browser → `localhost:8080` (port-forward) → `frontend-service:80` → frontend Pod `:5000`.
2. Frontend `GET http://catalog-service:5000/products`.
3. Cluster DNS resolves `catalog-service` → Service ClusterIP.
4. Service forwards the connection to one ready catalog Pod (connection-based balancing).
5. Backend answers with the product list and `served_by` = Pod hostname; frontend relays it as JSON.

## Resource settings (each container)
| | CPU | Memory |
|---|---|---|
| Request | 100m | 128Mi |
| Limit | 500m | 256Mi |

Requests influence scheduling; limits cap usage (CPU is throttled, memory overuse can OOM-kill).

## Design decisions
- Separate folders, images, and Deployments → independent build/deploy/scale.
- `CATALOG_URL` environment variable → same code works locally (127.0.0.1) and in-cluster (DNS name).
- `imagePullPolicy: IfNotPresent` + `kind load docker-image` → no registry needed.
- `ClusterIP` + port-forward → no NodePort/LoadBalancer required for a local lab.
