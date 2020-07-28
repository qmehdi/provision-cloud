#!/bin/bash
max_retry=30
counter=0
echo "Installing External DNS via helm"
until helm install external-dns --namespace=kube-system stable/external-dns \
--namespace=kube-system \
-f ../../helm-services/external-dns/external-dns-values.yaml \

do
  [[ counter -eq $max_retry ]] && echo "Timed out!" && exit 1
  echo "Failed to apply External DNS, sleep 15 try again"
  sleep 15
  ((counter++))
done
echo "External DNS applied"
