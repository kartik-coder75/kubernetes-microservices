<#
 Runs the Kubernetes part of the lab end to end (Sections 6-15) on the dedicated
 'microservices-lab' Kind cluster and saves outputs to docs/outputs/.
 Run from the project root:   .\scripts\run-all.ps1
 Requires: Docker Desktop running, kind, kubectl. (Does NOT delete the cluster.)
#>
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$out = "docs\outputs"
New-Item -ItemType Directory -Force $out | Out-Null
$cluster = "microservices-lab"

function Section($title) { Write-Host "`n=== $title ===" -ForegroundColor Cyan }
function Run($file, [scriptblock]$cmd) {
    $text = "PS> $($cmd.ToString().Trim())`n" + ((& $cmd 2>&1 | Out-String))
    Write-Host $text
    Add-Content -Path (Join-Path $out $file) -Value $text
}
function Fresh($file) { if (Test-Path (Join-Path $out $file)) { Remove-Item (Join-Path $out $file) } }

Section "1. Software checks"
Fresh "02-software-check.txt"
Run "02-software-check.txt" { docker --version }
Run "02-software-check.txt" { docker info --format "{{.ServerVersion}}" }
Run "02-software-check.txt" { py --version }
Run "02-software-check.txt" { kind version }
Run "02-software-check.txt" { kubectl version --client }

Section "6. Build images"
Fresh "03-docker-build.txt"
Run "03-docker-build.txt" { docker build -t catalog:v1 .\backend }
Run "03-docker-build.txt" { docker build -t frontend:v1 .\frontend }
Run "03-docker-build.txt" { docker images }

Section "7. Cluster"
Fresh "04-cluster.txt"
if (-not ((kind get clusters 2>$null) -contains $cluster)) {
    kind create cluster --name $cluster --config kind-config.yaml
}
kubectl config use-context "kind-$cluster" | Out-Null
Run "04-cluster.txt" { kubectl config current-context }
Run "04-cluster.txt" { kubectl get nodes -o wide }
Run "04-cluster.txt" { kind load docker-image catalog:v1 frontend:v1 --name microservices-lab }

Section "9. Deploy"
Fresh "05-deploy.txt"
Run "05-deploy.txt" { kubectl apply -f deployment.yaml }
kubectl rollout status deployment/catalog-deployment --timeout=180s
kubectl rollout status deployment/frontend-deployment --timeout=180s
Run "05-deploy.txt" { kubectl get deployments }
Run "05-deploy.txt" { kubectl get pods -o wide }
Run "05-deploy.txt" { kubectl get services }

Section "10. Test + service discovery"
Fresh "06-service-discovery.txt"
$pf = Start-Process kubectl -ArgumentList "port-forward","service/frontend-service","8080:80" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 5
try {
    Run "06-service-discovery.txt" { Invoke-RestMethod http://localhost:8080/products | ConvertTo-Json -Compress }
    Run "06-service-discovery.txt" { kubectl exec deployment/frontend-deployment -- python -c "import socket; print(socket.gethostbyname('catalog-service'))" }
    Run "06-service-discovery.txt" { kubectl get svc catalog-service }
    Run "06-service-discovery.txt" { kubectl get endpoints catalog-service }
    Run "06-service-discovery.txt" { kubectl get endpointslices -l kubernetes.io/service-name=catalog-service }

    Section "11. Scale backend"
    Fresh "07-scaling.txt"
    Run "07-scaling.txt" { kubectl get pods -l app=catalog -o wide }
    Run "07-scaling.txt" { kubectl scale deployment catalog-deployment --replicas=3 }
    kubectl rollout status deployment/catalog-deployment --timeout=180s
    Run "07-scaling.txt" { kubectl get pods -l app=catalog -o wide }
    Run "07-scaling.txt" { kubectl get endpoints catalog-service }
    Run "07-scaling.txt" { kubectl get endpointslices -l kubernetes.io/service-name=catalog-service }
    Run "07-scaling.txt" { 1..6 | ForEach-Object { (Invoke-RestMethod http://localhost:8080/products).served_by } }
}
finally {
    if ($pf -and -not $pf.HasExited) { Stop-Process -Id $pf.Id -Force }
}

Section "12. curl client load-balancing test"
Fresh "08-load-balancing.txt"
kubectl delete pod curl-client --ignore-not-found | Out-Null
kubectl run curl-client --image=curlimages/curl:8.12.1 --restart=Never --command -- sleep 3600 | Out-Null
kubectl wait --for=condition=Ready pod/curl-client --timeout=120s | Out-Null
Run "08-load-balancing.txt" { kubectl get pod curl-client }
$loop = 'i=1; while [ $i -le 12 ]; do curl -s -H "Connection: close" http://catalog-service:5000/products; echo; i=$((i+1)); done'
Run "08-load-balancing.txt" { kubectl exec curl-client -- sh -c $loop }
kubectl delete pod curl-client | Out-Null

Section "13. Resource allocation"
Fresh "09-resources.txt"
$pod = (kubectl get pods -l app=catalog -o jsonpath="{.items[0].metadata.name}")
Run "09-resources.txt" { kubectl describe pod $pod }
Run "09-resources.txt" { kubectl describe nodes }

Section "14. Scheduling test"
Fresh "10-scheduling.txt"
Run "10-scheduling.txt" { kubectl apply -f resource-test.yaml }
Start-Sleep -Seconds 20
Run "10-scheduling.txt" { kubectl get pod resource-test }
Run "10-scheduling.txt" { kubectl describe pod resource-test }
Run "10-scheduling.txt" { kubectl delete pod resource-test }
Fresh "10b-top.txt"
Run "10b-top.txt" { kubectl top nodes }   # may report Metrics API unavailable on default Kind

Section "15. Final verification"
Fresh "11-final-verification.txt"
Run "11-final-verification.txt" { kubectl get nodes }
Run "11-final-verification.txt" { kubectl get deployments }
Run "11-final-verification.txt" { kubectl get pods -o wide }
Run "11-final-verification.txt" { kubectl get services }
Run "11-final-verification.txt" { kubectl get endpoints catalog-service }

Write-Host "`nDone. Outputs saved in docs\outputs. Add screenshots to docs\screenshots. Run scripts\cleanup.ps1 when finished." -ForegroundColor Green
