# Troubleshooting Guide

| Problem | What to check / solution |
|---|---|
| `docker info` cannot connect | Open Docker Desktop, wait until the engine is running, rerun `docker info`. |
| `kind` or `kubectl` not recognized | Tool not installed or not on PATH. Install it; restart VS Code. |
| Kind cluster already exists | `kind get clusters`, then `kubectl config use-context kind-microservices-lab`. |
| `ImagePullBackOff` / `ErrImageNeverPull` | `docker images`; `kind load docker-image catalog:v1 frontend:v1 --name microservices-lab`; check image tags in `deployment.yaml`. For nginx/curl images check internet access. |
| Pod is `Pending` | `kubectl describe pod POD_NAME` → Events; check node capacity and requested resources. |
| Pod is `CrashLoopBackOff` | `kubectl logs POD_NAME`; check Python syntax, dependency names, startup command. |
| Browser cannot open `localhost:8080` | Is port-forward still running? Does `frontend-service` exist? Is the frontend Pod Ready? |
| Frontend returns 502 | Check backend Pods, `catalog-service`, endpoints. `kubectl logs deployment/frontend-deployment` and `kubectl logs deployment/catalog-deployment`. |
| `catalog-service` DNS does not resolve | Service in same namespace? Frontend Pod running? `kubectl get svc catalog-service`. |
| `kubectl apply` YAML error | Spaces only (no Tabs); `---` separators on their own lines. |
| `kubectl top` Metrics API unavailable | Metrics Server not installed. Skip; use `describe pod` / `describe nodes`. |
| Local test: port already in use | Close old terminals/Flask processes; make sure `PORT` env var is not left over from an earlier session. |

## Useful diagnostics
```powershell
kubectl get all
kubectl get pods -o wide
kubectl describe pod POD_NAME
kubectl logs POD_NAME
kubectl get svc
kubectl get endpoints catalog-service
```
