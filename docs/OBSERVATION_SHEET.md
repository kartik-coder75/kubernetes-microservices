# Student Observation Sheet

"Expected" values come from the lab configuration. **Replace the Student result column with what you actually saw** and attach screenshots in `docs/screenshots/`.

| Observation | Expected / configured value | Student result |
|---|---|---|
| Name of the Docker backend image | `catalog:v1` | |
| Name of the Docker frontend image | `frontend:v1` | |
| Kind cluster name | `microservices-lab` | |
| Number of Kubernetes nodes | 3 (1 control-plane + 2 workers) | |
| Initial backend replica count | 1 | |
| Backend replica count after scaling | 3 | |
| Backend Service name | `catalog-service` | |
| Frontend Service name | `frontend-service` | |
| CPU request configured for backend | `100m` | |
| Memory request configured for backend | `128Mi` | |
| Reason `resource-test` Pod remained Pending | Requested 100 CPU / 100Gi memory; no node has that available (workers: Insufficient cpu / memory; control-plane: untolerated taint) | |
