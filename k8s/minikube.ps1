# Appelle minikube par chemin complet (contourne le PATH sous Cursor/VS Code)
$minikubeDir = "C:\Program Files\Kubernetes\Minikube"
$minikubeExe = Join-Path $minikubeDir "minikube.exe"
if (-not (Test-Path $minikubeExe)) {
    Write-Error "Minikube introuvable: $minikubeExe"
    exit 1
}
& $minikubeExe @args
