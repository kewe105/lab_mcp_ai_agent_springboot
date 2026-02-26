# STEP 12 — Deploy on Minikube (Local Kubernetes)

Déploiement de **ai-agent** (Spring Boot) et **github-mcp-server** (MCP GitHub) sur un cluster Kubernetes local.

- **ai-agent** appelle le MCP via le service ClusterIP `http://github-mcp-server:3333/mcp`
- Les appels à Claude (Anthropic) partent du cluster vers l’extérieur en HTTPS

---

## 12.1 Prérequis (Windows)

### 1. Installer kubectl

PowerShell (en administrateur si besoin) :

```powershell
winget install -e --id Kubernetes.kubectl
```

Ferme et rouvre le terminal, puis vérifie :

```powershell
kubectl version --client
```

### 2. Installer Minikube

```powershell
winget install Kubernetes.minikube
```

Ferme et rouvre le terminal, puis vérifie :

```powershell
minikube version
```

**Si `minikube` n’est pas reconnu** après installation : le dossier d’installation n’est peut‑être pas dans le PATH. Deux solutions :

**A) Pour cette session uniquement** (à coller dans le terminal) :

```powershell
$env:Path += ";C:\Program Files\Kubernetes\Minikube"
minikube version
```

**B) Script fourni** (depuis la racine du repo, sans modifier le PATH) :

```powershell
.\k8s\minikube.ps1 version
.\k8s\minikube.ps1 start --cpus=4 --memory=8192
```

**C) Pour que `minikube` soit reconnu dans tous les terminaux** : ouvre PowerShell **en tant qu’administrateur**, puis exécute une fois :

```powershell
$minikubeDir = "C:\Program Files\Kubernetes\Minikube"
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($machinePath -notlike "*$minikubeDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$machinePath;$minikubeDir", "Machine")
}
```
Puis ferme et rouvre tous les terminaux (y compris Cursor).

### 3. Docker

Docker Desktop doit être installé et démarré (utilisé par Minikube comme driver par défaut).

---

## 12.2 Démarrer Minikube et créer le namespace

Utilise une mémoire **inférieure à celle allouée à Docker Desktop** (voir Paramètres → Resources de Docker Desktop). Souvent 3072 ou 2048 suffisent :

```powershell
minikube start --cpus=2 --memory=3072
kubectl create ns lab-agent
```

Si Docker Desktop a peu de RAM (ex. 3–4 Go), utilise `--memory=2048`.

---

## 12.3 Build des images et chargement dans Minikube

Sous **PowerShell**, `eval $(minikube docker-env)` ne fonctionne pas. Utilise **Option B** : build local puis chargement.

### Image ai-agent (depuis la racine du repo)

```powershell
cd C:\Users\Kewe\IdeaProjects\lab_mcp_ai_agent_springboot\agent
docker build -t ai-agent:dev .
minikube image load ai-agent:dev
cd ..
```

### Image github-mcp-server

Cloner le repo officiel, build, charger dans Minikube :

```powershell
cd C:\Users\Kewe\IdeaProjects\lab_mcp_ai_agent_springboot
git clone https://github.com/github/github-mcp-server.git
cd github-mcp-server
docker build -t github-mcp-server:dev .
minikube image load github-mcp-server:dev
cd ..
```

Si le projet GitHub MCP utilise une autre commande de build, suis son README. L’image doit s’appeler **github-mcp-server:dev**.

---

## 12.4 Créer le secret (Anthropic + GitHub)

Définis d’abord tes clés en variable d’environnement (ou remplace dans la commande) :

```powershell
$env:ANTHROPIC_API_KEY = "ta-clé-anthropic"
$env:GITHUB_TOKEN = "ta-clé-github"
```

Puis crée le secret dans le namespace `lab-agent` :

```powershell
kubectl -n lab-agent create secret generic agent-secrets `
  --from-literal=ANTHROPIC_API_KEY="$env:ANTHROPIC_API_KEY" `
  --from-literal=GITHUB_TOKEN="$env:GITHUB_TOKEN"
```

---

## 12.5 Déployer le GitHub MCP Server

Depuis la **racine du repo** (là où se trouve le dossier `k8s/`) :

```powershell
kubectl apply -f k8s/github-mcp.yaml
```

---

## 12.6 Déployer l’AI Agent

```powershell
kubectl apply -f k8s/ai-agent.yaml
```

---

## 12.7 Vérifications

Pods et services :

```powershell
kubectl -n lab-agent get pods
kubectl -n lab-agent get svc
```

Accéder à l’agent depuis ta machine (tunnel Minikube) :

```powershell
minikube service -n lab-agent ai-agent --url
```

Tu peux appeler cette URL (ex. `http://<ip>:<port>/api/users`) pour tester.

---

## Dépannage

- **ai-agent en `ErrImagePull`** : l’image n’est pas dans Minikube. Rebuild et recharger, puis redémarrer les pods :
  ```powershell
  cd agent
  docker build -t ai-agent:dev .
  minikube image load ai-agent:dev
  cd ..
  kubectl -n lab-agent delete pod -l app=ai-agent
  ```
- **github-mcp-server en `CrashLoopBackOff`** : le déploiement a été mis à jour pour lancer le serveur en mode **http** sur le port 3333 et pour définir `GITHUB_PERSONAL_ACCESS_TOKEN`. Réapplique le manifeste et redémarre le pod :
  ```powershell
  kubectl apply -f k8s/github-mcp.yaml
  kubectl -n lab-agent delete pod -l app=github-mcp-server
  ```
  Vérifier les logs en cas d’échec : `kubectl -n lab-agent logs -l app=github-mcp-server --tail=100`

---

## Résumé des fichiers

| Fichier | Rôle |
|--------|------|
| `k8s/github-mcp.yaml` | Deployment + Service du serveur MCP GitHub (port 3333) |
| `k8s/ai-agent.yaml` | Deployment + Service de l’app Spring Boot (port 8080), avec `MCP_BASE_URL` et `MCP_PATH` pour joindre le MCP dans le cluster |
| `agent/src/main/resources/application.yml` | `mcp.base-url` et `mcp.path` lisent `MCP_BASE_URL` et `MCP_PATH` (défauts : localhost:3333, /mcp) |

Les secrets restent hors des images et hors Git ; ils sont injectés via le secret Kubernetes `agent-secrets`.
