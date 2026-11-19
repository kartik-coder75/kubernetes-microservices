# Microservices Web Application & Kubernetes Resource Management

**Cloud Computing Lab** | Windows 11 · VS Code · Docker Desktop · Kind · kubectl · Python Flask

A small **Product Management** web application made of two microservices (a *frontend* and a *backend / catalog* service). Both are packaged with Docker, deployed on a three-node Kind Kubernetes cluster, connected through Kubernetes DNS service discovery, scaled to three backend replicas, and used to study CPU/memory requests, limits and Pod scheduling.

## Experiment objectives
- Analyse resource allocation, scheduling and load balancing in Kubernetes.
- Build and deploy a microservices-based web application with service discovery and load balancing.

## Learning outcomes
- Explain why an application can be divided into independent microservices.
- Build a simple Flask application and package it into Docker images.
- Deploy containers using Kubernetes Deployments and Services.
- Explain how Kubernetes DNS enables service discovery.
- Scale backend replicas and observe Service endpoint changes.
- Distinguish CPU/memory requests from limits and inspect Pod scheduling.

---

## Repository structure

```
microservice-project/
|-- backend/
|   |-- app.py                  # Flask catalog API (/products, /health)
|   |-- requirements.txt        # flask
|   `-- Dockerfile
|-- frontend/
|   |-- app.py                  # Flask frontend, calls catalog-service
|   |-- requirements.txt        # flask, requests
|   `-- Dockerfile
|-- kind-config.yaml            # 1 control-plane + 2 workers
|-- deployment.yaml             # 2 Deployments + 2 Services
|-- resource-test.yaml          # intentionally unschedulable Pod
|-- scripts/
|   |-- run-all.ps1             # runs Sections 6-15 end to end and saves outputs
|   `-- cleanup.ps1             # deletes the app and the microservices-lab cluster
|-- docs/
|   |-- ARCHITECTURE.md
|   |-- TROUBLESHOOTING.md
|   |-- OBSERVATION_SHEET.md
|   |-- VIVA_QUESTIONS.md       # questions with model answers
|   |-- outputs/                # command outputs (01 = local test, 02+ = cluster run)
|   `-- screenshots/            # add your screenshots here
|-- .gitignore
`-- .dockerignore
```

## Architecture (short)

```
Browser --(port-forward 8080)--> frontend-service:80 --> frontend Pod (Flask :5000)
                                                              |
                                              http://catalog-service:5000/products  (Kubernetes DNS)
                                                              v
                                   catalog-service:5000 (ClusterIP) --> catalog Pod x1..3 (Flask :5000)
```
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

---

## How to use this guide
Complete one numbered step, understand the meaning and expected result, then move on. Commands are for **PowerShell** in the VS Code terminal. Use only the dedicated cluster **`microservices-lab`**.

> **Shortcut:** after Section 1, `./scripts/run-all.ps1` runs Sections 6-15 automatically and saves outputs into `docs/outputs/`. The manual steps below explain what each stage does.

---

## 1. Before starting: check the software

**Step 1 - Open Docker Desktop** (Start → type *Docker Desktop*). Wait until the engine shows *running*. Kind nodes run as Docker containers, so Docker must be running first.

**Step 2 - Open Visual Studio Code.**

**Step 3 - Open a PowerShell terminal:** Terminal → New Terminal (use the arrow beside **+** to choose PowerShell if needed). The prompt starts with `PS`.

Run the software checks:

```powershell
docker --version
docker info
py --version
kind version
kubectl version --client
```

- `docker info` must return server information. If it cannot connect to the daemon, wait for Docker Desktop to finish starting.
- If a command is not recognized, install that tool and restart VS Code.
- An internet connection is needed (Kind node image, `nginx`, `curl` images).

## 2. Create the project in Visual Studio Code

**Step 4 - Create the main folder.** In File Explorer: `C:\CC-Lab\microservice-project`.

**Step 5 - Open it in VS Code:** File → Open Folder → select `C:\CC-Lab\microservice-project` → trust the authors. (Or `git clone` this repository and open the folder.)

**Step 6 - Create the `backend` and `frontend` folders** with the Explorer *New Folder* icon.

```
microservice-project/
|-- backend/
|-- frontend/
```

## 3. Build the backend microservice

**Step 7 - `backend/app.py`** (see the file in this repo). `/products` returns the product list and `socket.gethostname()` (the Pod name in Kubernetes); `/health` returns `{"status": "healthy"}`; `host="0.0.0.0"` lets it accept requests from outside its container.

**Step 8 - `backend/requirements.txt`** containing `flask`.

## 4. Build the frontend microservice

**Step 9 - `frontend/app.py`** (see the file in this repo). It serves a home page and a `/products` route that calls the backend at `CATALOG_URL` (default `http://catalog-service:5000`). On error it returns HTTP 502.

`catalog-service` is not a registered website name — it will be the **Kubernetes Service name**, resolved by Kubernetes DNS. For the local test we override it with `127.0.0.1`.

**Step 10 - `frontend/requirements.txt`** containing `flask` and `requests`.

## 5. Test both services on your computer

Backend on port 5000, frontend on port 5001. Both terminals stay open during the test.

**Step 11 - Create a virtual environment** (project root):

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install flask requests
```

**Step 12 - Start the backend** (terminal 1, leave it running):

```powershell
.\.venv\Scripts\python.exe .\backend\app.py
```

**Step 13 - Start the frontend** (terminal 2):

```powershell
$env:CATALOG_URL = "http://127.0.0.1:5000"
$env:PORT = "5001"
.\.venv\Scripts\python.exe .\frontend\app.py
```

**Step 14 - Test in the browser:** open `http://localhost:5001` → click **View Products**. Expected: `Laptop, Mobile, Keyboard` and a `served_by` hostname (your computer's name).

Stop both apps with `Ctrl+C` and **close both terminals** so `PORT` / `CATALOG_URL` do not carry over.

Captured output: [docs/outputs/01-local-test.txt](docs/outputs/01-local-test.txt)

## 6. Create Dockerfiles and build images

**Step 15 - `backend/Dockerfile`** and **Step 16 - `frontend/Dockerfile`** (identical content, built from each folder):

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
```

**Step 17 - Build the images** (from the project root, in a new terminal):

```powershell
docker build -t catalog:v1 .\backend
docker build -t frontend:v1 .\frontend
```

**Step 18 - Confirm the images exist:**

```powershell
docker images
```

> **Image vs container:** an image is the packaged template; a container is a running instance of it. Kubernetes runs containers from these images inside Pods.

## 7. Create a three-node Kubernetes cluster

**Step 19 - `kind-config.yaml`** (one control-plane, two workers):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

**Step 20 - Create the cluster** (first run downloads the node image, a few minutes):

```powershell
kind get clusters
kind create cluster --name microservices-lab --config kind-config.yaml
```

If `microservices-lab` already exists, do **not** create it again:

```powershell
kubectl config use-context kind-microservices-lab
```

**Step 21 - Select and verify the cluster:**

```powershell
kubectl config use-context kind-microservices-lab
kubectl get nodes -o wide
```
Expected: 1 control-plane + 2 worker nodes, all `Ready`.

**Step 22 - Load the images into Kind** (Kind nodes cannot see the host Docker image cache):

```powershell
kind load docker-image catalog:v1 frontend:v1 --name microservices-lab
```

## 8. Create the Kubernetes deployment file

**Step 23 - `deployment.yaml`** creates four resources separated by `---`: `catalog-deployment`, `catalog-service`, `frontend-deployment`, `frontend-service`. See the [file](deployment.yaml).

Key points:
- `replicas: 1` – one Pod per Deployment at the start.
- `image: catalog:v1` / `frontend:v1` with `imagePullPolicy: IfNotPresent` – use the image already loaded into Kind.
- `selector` / `labels` – how a Service finds its Pods.
- `ClusterIP` – internal address; the browser reaches the frontend through port-forward.
- Resources per container: requests `cpu 100m`, `memory 128Mi`; limits `cpu 500m`, `memory 256Mi`.
- The backend Service name **`catalog-service`** must match the hostname used in `frontend/app.py`.

> YAML is indentation-sensitive: spaces only, never Tab.

## 9. Deploy the application

**Step 24 - Apply:**
```powershell
kubectl apply -f deployment.yaml
```
Expected: 2 Deployments and 2 Services created.

**Step 25 - Deployments** (wait until AVAILABLE = 1 for both):
```powershell
kubectl get deployments
```

**Step 26 - Pods** (one catalog + one frontend, both `Running`):
```powershell
kubectl get pods
kubectl get pods -o wide
```

**Step 27 - Services** (`catalog-service` 5000, `frontend-service` 80, both ClusterIP):
```powershell
kubectl get services
```

If a Pod is not running:
```powershell
kubectl describe pod POD_NAME
kubectl logs POD_NAME
```

## 10. Test the application and service discovery

**Step 28 - Expose the frontend** (keep this terminal open; use new terminals afterwards):
```powershell
kubectl port-forward service/frontend-service 8080:80
```

**Step 29 - Open** `http://localhost:8080` → **View Products**. `served_by` is now the backend **Pod name**.

**Step 30 - Prove Kubernetes DNS resolves the backend Service** (second terminal):
```powershell
kubectl exec deployment/frontend-deployment `
  -- python -c "import socket; print(socket.gethostbyname('catalog-service'))"
```
Expected: the Service ClusterIP.

**Service discovery explained:** the frontend calls `http://catalog-service:5000/products`. Kubernetes DNS resolves `catalog-service` to the Service IP; the Service selects Pods labelled `app: catalog` and forwards to a ready endpoint. Pod IPs change; the Service name is stable.

Inspect the network:
```powershell
kubectl get svc catalog-service
kubectl get endpoints catalog-service
kubectl get endpointslices -l kubernetes.io/service-name=catalog-service
```
> Newer kubectl may print a deprecation warning for `endpoints` (replaced by EndpointSlices). The output is still valid.

## 11. Scale the backend and observe load balancing

**Step 31 - Baseline** (one backend Pod):
```powershell
kubectl get pods -l app=catalog -o wide
```

**Step 32 - Scale to three replicas** (wait for `1/1 Running` on all):
```powershell
kubectl scale deployment catalog-deployment --replicas=3
kubectl get pods -l app=catalog -o wide
```

**Step 33 - Inspect Service endpoints** (three Pod IPs once Ready):
```powershell
kubectl get endpoints catalog-service
kubectl get endpointslices -l kubernetes.io/service-name=catalog-service
```

**Step 34 - Refresh** `http://localhost:8080/products` several times (the port-forward from Step 28 must still run). `served_by` may change between the three Pod names.

> **Load-balancing note:** Service routing is *connection-based*, not guaranteed round-robin per HTTP request, so results may not alternate evenly. Use Section 12 for a controlled demo.

## 12. Optional: watch requests reach different Pods

**Step 35 - Temporary curl client Pod:**
```powershell
kubectl run curl-client --image=curlimages/curl:8.12.1 --restart=Never --command -- sleep 3600
kubectl wait --for=condition=Ready pod/curl-client --timeout=120s
kubectl get pod curl-client
```

**Step 36 - Shell inside it:**
```powershell
kubectl exec -it curl-client -- sh
```

**Step 37 - Twelve requests** (run *inside* the curl-client shell — these are `sh` commands, not PowerShell):
```sh
i=1
while [ $i -le 12 ]; do
  curl -s -H "Connection: close" http://catalog-service:5000/products
  echo
  i=$((i+1))
done
```
Type `exit`, then delete the Pod from Windows:
```powershell
kubectl delete pod curl-client
```

**Notice:** the client always uses the same Service name, the Service has three ready endpoints, and new connections may be served by different Pods.

## 13. Study CPU and memory resource allocation

| Setting | Meaning |
|---|---|
| CPU request `100m` | The container requests 0.1 CPU core for scheduling. |
| Memory request `128Mi` | The container requests 128 MiB for scheduling. |
| CPU limit `500m` | The container can use up to 0.5 core; excess use is throttled. |
| Memory limit `256Mi` | The container is limited to 256 MiB; exceeding it can cause an OOM kill. |

Requests = space the Scheduler reserves on a node. Limits = maximum allowed usage.

**Step 38 - Inspect the backend Pod's resources** (find *Requests* / *Limits* under *Containers*):
```powershell
kubectl get pods -l app=catalog
kubectl describe pod POD_NAME
```

**Step 39 - Node capacity and allocation** (scroll to *Capacity*, *Allocatable*, *Allocated resources*):
```powershell
kubectl describe nodes
```

## 14. Observe resource usage and Pod scheduling

### 14.1 Optional: actual usage (needs Metrics Server; not in default Kind)
```powershell
kubectl top nodes
kubectl top pods
```
If the Metrics API is unavailable, skip. Requests/limits are *configuration*; `kubectl top` shows *measured usage*.

### 14.2 A Pod that cannot fit

**Step 40 - `resource-test.yaml`** requests **100 CPU cores and 100 GiB** memory (intentionally unrealistic). See the [file](resource-test.yaml).

**Step 41 - Apply** (wait 10–20 s):
```powershell
kubectl apply -f resource-test.yaml
kubectl get pod resource-test
```
Expected: `Pending`.

**Step 42 - Read the reason:**
```powershell
kubectl describe pod resource-test
```
Look in *Events* for `FailedScheduling`, e.g. `0/3 nodes are available: 1 node(s) had untolerated taint, 2 Insufficient cpu, 2 Insufficient memory.` The control-plane node is tainted; the workers fail on resources.

**Step 43 - Delete it:**
```powershell
kubectl delete pod resource-test
```

## 15. Final verification and cleanup

### 15.1 Verify
```powershell
kubectl get nodes
kubectl get deployments
kubectl get pods -o wide
kubectl get services
kubectl get endpoints catalog-service
```

| Check | Expected |
|---|---|
| Nodes | 1 control-plane + 2 workers, `Ready` |
| Deployments | `frontend-deployment` 1 available; `catalog-deployment` 3 |
| Pods | 1 frontend + 3 backend, `Running` & Ready |
| Services | `catalog-service`, `frontend-service` (ClusterIP) |
| Endpoints | `catalog-service` → 3 backend Pods |

### 15.2 Stop the port-forward
`Ctrl+C` in the port-forward terminal (this does not delete the application).

### 15.3 Remove the application and cluster
Only when you have finished and no longer need the dedicated cluster:
```powershell
kubectl delete -f deployment.yaml
kind delete cluster --name microservices-lab
```
(or run `./scripts/cleanup.ps1`).

---

## 16. Troubleshooting (summary)

| Problem | Fix |
|---|---|
| `docker info` cannot connect | Start Docker Desktop, wait for engine, rerun. |
| `kind` / `kubectl` not recognized | Install, add to PATH, restart VS Code. |
| Kind cluster already exists | `kind get clusters`, then `kubectl config use-context kind-microservices-lab`. |
| `ImagePullBackOff` / `ErrImageNeverPull` | `docker images`; `kind load docker-image catalog:v1 frontend:v1 --name microservices-lab`; check tags. |
| Pod `Pending` | `kubectl describe pod POD_NAME` → Events. |
| `CrashLoopBackOff` | `kubectl logs POD_NAME`; check syntax / dependencies. |
| `localhost:8080` not opening | Port-forward still running? Service exists? Frontend Pod Ready? |
| Frontend 502 | Check backend Pods, `catalog-service`, endpoints, logs. |
| DNS does not resolve | Same namespace? Frontend Pod running? `kubectl get svc catalog-service`. |
| `kubectl apply` YAML error | Spaces only (no Tabs); `---` on its own lines. |
| `kubectl top` unavailable | Metrics Server missing; skip. |

Full table and diagnostics: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 17. Student observation sheet
See [docs/OBSERVATION_SHEET.md](docs/OBSERVATION_SHEET.md).

## 18. Viva questions
See [docs/VIVA_QUESTIONS.md](docs/VIVA_QUESTIONS.md) (with model answers).

## Final concept
Microservices split an application into smaller services. Docker packages each service. Kubernetes deploys and manages the containers. Services provide stable communication and load balancing. Resource requests and limits help Kubernetes allocate resources, while the Scheduler selects a suitable node for each Pod.

## Submission checklist
- [ ] Ran the experiment on my machine (`scripts/run-all.ps1` or manual steps)
- [ ] Outputs saved in `docs/outputs/`
- [ ] Screenshots added to `docs/screenshots/` (browser at :5001 and :8080, `kubectl get nodes/pods/endpoints`, `resource-test` Pending events)
- [ ] `docs/OBSERVATION_SHEET.md` verified against my own output
