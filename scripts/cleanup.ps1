# Removes the lab application and the dedicated 'microservices-lab' cluster ONLY.
# Run only when you are finished with the experiment.
Set-Location (Join-Path $PSScriptRoot "..")
$confirm = Read-Host "This deletes the 'microservices-lab' Kind cluster. Type YES to continue"
if ($confirm -ne "YES") { Write-Host "Cancelled."; exit }
kubectl config use-context kind-microservices-lab
kubectl delete -f deployment.yaml --ignore-not-found
kind delete cluster --name microservices-lab
