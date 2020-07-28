#!/bin/bash
max_retry=30
counter=0
echo "Installing nginx ingress via helm"
until helm install nginx --namespace kube-system stable/nginx-ingress \
--set rbac.create=true \
--set controller.scope.namespace=kube-system \
--set controller.ingressClass=nginx-ingress \
--set controller.stats.enabled=true \
--set controller.metrics.enabled=true \
--set controller.publishService.enabled=true \
--set controller.replicaCount=1 \
--set serviceAccount.create=true \
--set controller.service.nodePorts.http=30080 \
--set controller.service.nodePorts.https=30443 \
--set controller.scope.enabled=false \
-f ../../helm-services/nginx/internal-annotation-values.yaml \
-f ../../helm-services/nginx/internal-values.yaml
do
  [[ counter -eq $max_retry ]] && echo "Timed out!" && exit 1
  echo "Failed to apply nginx ingress, sleep 15 try again"
  sleep 15
  ((counter++))
done
echo "Nginx ingress applied"
