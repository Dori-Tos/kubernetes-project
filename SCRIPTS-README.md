# Scripts Usage Guide

This directory contains PowerShell scripts to manage your Movie Rating Kubernetes application.

## 🚀 Launch Script (`script_launch.ps1`)

**Purpose:** Deploys the complete Movie Rating application with ingress controller.

**Usage:**
```powershell
.\script_launch.ps1
```

**What it does:**
- ✅ Verifies Kubernetes cluster connectivity
- 📥 Installs/updates nginx ingress controller
- 📦 Deploys all application resources (pods, services, ingress)
- ⏳ Waits for resources to be ready
- 📊 Shows deployment status and access information

**After running:** Your app will be accessible at `http://movierating.local` (after adding hosts entry) or `http://localhost` with proper headers.

---

## 🧹 Cleanup Script (`script-cleanup.ps1`)

**Purpose:** Removes application resources and optionally the ingress controller.

**Usage:**
```powershell
# Complete cleanup (removes everything including ingress)
.\script-cleanup.ps1

# Keep ingress controller running (faster for development)
.\script-cleanup.ps1 -KeepIngress

# Skip confirmation prompt
.\script-cleanup.ps1 -Force

# Combine flags
.\script-cleanup.ps1 -KeepIngress -Force
```

**What it does:**
- 📊 Shows current resources before cleanup
- 🗑️ Removes all application pods, services, and ingress resources
- 🔌 Stops any active port-forwards
- 🗑️ Optionally removes nginx ingress controller
- ✅ Verifies cleanup completion

**Parameters:**
- `-KeepIngress`: Preserves the ingress controller (useful for development)
- `-Force`: Skips the confirmation prompt

---

## 🌐 DNS Configuration (One-time setup)

To access your app via `movierating.local`:

1. **Open PowerShell as Administrator**
2. **Add hosts entry:**
   ```powershell
   Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "127.0.0.1 movierating.local"
   ```

**To remove later:**
```powershell
# Open hosts file in notepad as Administrator
notepad C:\Windows\System32\drivers\etc\hosts
# Remove the line: 127.0.0.1 movierating.local
```

---

## 🧪 Testing Commands

```powershell
# Test via ingress with proper host header
Invoke-WebRequest -Uri http://localhost -Headers @{"Host"="movierating.local"}

# Test via domain name (after hosts file setup)  
Invoke-WebRequest -Uri http://movierating.local

# Check cluster status
kubectl get pods,svc,ingress
```

---

## 🔄 Development Workflow

```powershell
# Start development
.\script_launch.ps1

# Make changes to your code/configs...
# Apply changes
kubectl apply -f kubernetes/

# When done for the day (keep ingress for faster startup tomorrow)
.\script-cleanup.ps1 -KeepIngress

# Complete cleanup when switching projects
.\script-cleanup.ps1
```

---

## ❗ Troubleshooting

**If ingress controller fails to start:**
- Wait longer (it can take 2-3 minutes)
- Check Docker Desktop has enough resources
- Restart Docker Desktop

**If app doesn't respond:**
- Check pod status: `kubectl get pods`
- Check logs: `kubectl logs <pod-name>`
- Verify service: `kubectl get svc`

**If domain doesn't resolve:**
- Verify hosts file entry exists
- Try direct localhost access with Host header
- Clear DNS cache: `ipconfig /flushdns`