#!/bin/bash

minikube version
minikube start
KUBEIP=$(minikube ip)

kubectl version
kubectl cluster-info
kubectl get nodes

# deploy app nginx-1-12
APPNAME="nginx-1-12"

kubectl run $APPNAME --image=docker.io/nginx:1.12 --port=80

kubectl get deployments

POD_NAME=$(kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
echo Name of the Pod: $POD_NAME

# access app index home page
#curl http://localhost:8001/api/v1/proxy/namespaces/default/pods/$POD_NAME/

kubectl logs $POD_NAME

# label
kubectl label --record pods $POD_NAME app=$APPNAME
kubectl label --record deployments $APPNAME app=$APPNAME

kubectl expose deployment/$APPNAME --type="NodePort"  --port=80 --target-port=80

NODE_PORT=$(kubectl get services/$APPNAME -o go-template='{{(index .spec.ports 0).nodePort}}')

kubectl scale deployments/$APPNAME --replicas=4

kubectl describe deployments/$APPNAME

# loadbalancing is working now
curl -XGET http://$KUBEIP:$NODE_PORT

# rollout 
kubectl rollout deployments/$APPNAME

# update image
kubectl set image --record deployments/$APPNAME $APPNAME=nginx:1.13

# rollout undo
kubectl rollout history deployments/$APPNAME
kubectl rollout history deployment/$APPNAME --revision=1
kubectl rollout undo deployments/$APPNAME
kubectl rollout undo deployments/$APPNAME --to-revision=2

# resources limits
kubectl set resources --record deployment/$APPNAME -c=$APPNAME --limits=cpu=100m,memory=256Mi
