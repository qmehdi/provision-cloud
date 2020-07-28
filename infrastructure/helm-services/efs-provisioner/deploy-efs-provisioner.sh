#!/bin/bash
max_retry=30
counter=0
efs_filesystem_id=$1

echo "Installing efs provisioner via helm"
until \
helm install efs-provisioner --namespace=jenkins stable/efs-provisioner \
--set efsProvisioner.efsFileSystemId=${efs_filesystem_id} \
-f ../../helm-services/efs-provisioner/values.yaml --namespace=jenkins
do
  [[ counter -eq $max_retry ]] && echo "Timed out!" && exit 1
  echo "Failed to apply efs provisioner, sleep 15 try again"
  sleep 15
  ((counter++))
done
echo "EFS Provisioner applied"
