## Be in mongodb folder
cd ..\..\kubernetes\mongodb

git clone https://github.com/mongodb/mongodb-kubernetes-operator.git

kubectl apply -f .\mongodb-kubernetes-operator\config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml

kubectl apply -n test -k config/rbac/

kubectl apply -n test -k .\mongodb-kubernetes-operator\config/rbac/

## Replace <your-password-here> in config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml to the password you wish to use

kubectl create -n test -f .\mongodb-kubernetes-operator\config/manager/manager.yaml

kubectl apply -n test -f .\kubernetes\mongodb\mongodb-kubernetes-operator\config/samples/mongodb.com_v1_mongodbcommunity_cr.yaml

## Generate Secrets

kubectl apply -f .\kubernetes\mongodb\mongodb-auth-setup.yaml

kubectl get secret example-mongodb-admin-admin-user -n default -o json | jq -r '.data | with_entries(.value |= @base64d)'
kubectl get secret example-mongodb-admin-app-user -n default -o json | jq -r '.data | with_entries(.value |= @base64d)'      
