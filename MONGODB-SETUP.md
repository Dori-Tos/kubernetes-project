# Production MongoDB Setup Guide

This guide explains how to set up the production MongoDB environment from scratch.

## Prerequisites

1. **Kubernetes cluster** with kubectl access
2. **MongoDB Community Operator** installed
3. **FluxCD** installed in production namespace

## Automated Setup (Recommended)

### Option 1: Using the Setup Script

```bash
# Navigate to the mongodb directory
cd kubernetes/mongodb/

# Run the setup script (Linux/Mac)
chmod +x setup-mongodb-operator.sh
./setup-mongodb-operator.sh

# Or run the PowerShell script (Windows)
.\setup-mongodb-operator.ps1
```

### Option 2: Using FluxCD (Fully Automated)

If FluxCD is watching your repository, it will automatically apply the MongoDB operator RBAC and service accounts. However, you still need to patch the operator manually:

```bash
# Apply the operator patch to enable multi-namespace support
kubectl patch deployment mongodb-kubernetes-operator -n default --patch-file kubernetes/mongodb/mongodb-operator-patch.yaml

# Restart the operator
kubectl rollout restart deployment/mongodb-kubernetes-operator -n default
```

## Manual Setup (Step by Step)

If you prefer to set up manually or need to troubleshoot:

### 1. Install MongoDB Community Operator (if not installed)

```bash
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml
```

### 2. Set Up Multi-Namespace Support

```bash
# Apply cluster-wide RBAC permissions
kubectl apply -f kubernetes/mongodb/mongodb-operator-cluster-permissions.yaml

# Create required service accounts
kubectl apply -f kubernetes/mongodb/mongodb-service-accounts.yaml

# Patch operator to watch all namespaces
kubectl patch deployment mongodb-kubernetes-operator -n default --patch-file kubernetes/mongodb/mongodb-operator-patch.yaml

# Restart operator
kubectl rollout restart deployment/mongodb-kubernetes-operator -n default
```

### 3. Deploy Production MongoDB

```bash
# Apply production MongoDB configuration
kubectl apply -k kubernetes/mongodb/prod/
```

## Verification

### Check Operator Status
```bash
# Check operator is running
kubectl get pods -n default -l name=mongodb-kubernetes-operator

# Check operator logs (should show no permission errors)
kubectl logs -n default deployment/mongodb-kubernetes-operator --tail=20
```

### Check MongoDB Deployment
```bash
# Check MongoDB resources
kubectl get mongodbcommunity -n production

# Check MongoDB pods
kubectl get pods -n production | grep mongodb

# Check MongoDB StatefulSet
kubectl get statefulset -n production
```

### Check Application Connectivity
```bash
# Check if connection secrets were created
kubectl get secrets -n production | grep mongodb-admin

# Check application pods
kubectl get pods -n production | grep movie-rating
```

## Troubleshooting

### Operator Permission Issues
- Ensure `mongodb-kubernetes-operator-cluster-wide` ClusterRoleBinding exists
- Check operator logs for "forbidden" errors
- Restart the operator after applying new permissions

### MongoDB Pods Not Starting
- Check if `mongodb-database` service account exists in the target namespace
- Check StatefulSet events: `kubectl describe statefulset production-mongodb -n production`
- Verify PVC creation and storage availability

### Application Connection Issues
- Ensure MongoDB is in "Running" phase: `kubectl get mongodbcommunity production-mongodb -n production`
- Check if connection secrets exist: `kubectl get secrets -n production | grep mongodb-admin`
- Verify RBAC permissions for application service account

## Files Reference

- `mongodb-operator-cluster-permissions.yaml` - Cluster-wide RBAC for the operator
- `mongodb-service-accounts.yaml` - Required service accounts
- `mongodb-operator-patch.yaml` - Patches operator for multi-namespace support
- `prod/mongodb-setup.yaml` - Production MongoDB configuration
- `setup-mongodb-operator.sh` - Automated setup script (Linux/Mac)
- `setup-mongodb-operator.ps1` - Automated setup script (Windows)