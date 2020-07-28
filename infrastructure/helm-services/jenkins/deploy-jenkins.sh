#!/bin/bash
max_retry=30
counter=0
echo "Installing jenkins via helm"
until helm install jenkins --namespace=jenkins ../../helm-services/jenkins/helm/charts/stable/jenkins \
-f ../../helm-services/jenkins/helm/values.yaml --namespace=jenkins
do
  [[ counter -eq $max_retry ]] && echo "Timed out!" && exit 1
  echo "Failed to apply jenkins, sleep 15 try again"
  sleep 15
  ((counter++))
done
echo "jenkins applied"
