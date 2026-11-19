# Viva Questions with Model Answers

1. **Why separate frontend and backend microservices?**
   Each service has one focused responsibility, its own dependencies, and can be built, deployed, scaled and fixed independently.

2. **Docker image vs container?**
   An image is the packaged, read-only template (code + dependencies + start command). A container is a running instance created from an image.

3. **What is a Pod?**
   The smallest deployable unit in Kubernetes; it wraps one or more containers sharing network and storage. Here each Pod has one application container.

4. **Role of a Deployment?**
   It declares the desired state (image, replica count, resources) and keeps that many Pods running, replacing failed ones and supporting scaling and updates.

5. **Purpose of `catalog-service`?**
   A stable internal name and virtual IP for all backend Pods labelled `app: catalog`, so the frontend never needs individual Pod IPs.

6. **How does Kubernetes DNS help service discovery?**
   Cluster DNS resolves a Service name (`catalog-service`) to its ClusterIP, so services find each other by name even though Pod IPs change.

7. **What changed when backend replicas went from 1 to 3?**
   Two more catalog Pods were created; once Ready they were added to the Service endpoints (three Pod IPs), so new connections can be spread across three backends and availability improves.

8. **CPU request vs CPU limit?**
   The request is what the Scheduler reserves/uses to decide placement (100m). The limit is the maximum the container may use (500m); excess CPU use is throttled.

9. **Which component selects the node for a new Pod?**
   The kube-scheduler (on the control plane).

10. **Why did `resource-test` stay Pending?**
    It requested 100 CPU and 100Gi memory; no worker node had that much allocatable, and the control-plane node is tainted, so the Scheduler reported `FailedScheduling` (Insufficient cpu/memory).
