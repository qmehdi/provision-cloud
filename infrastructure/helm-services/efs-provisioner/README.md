### Create an EFS Backed Volume

In case of Kubernetes Volumes, once the Pod is deleted the specification of the volume in the Pod is also lost so from Kubernetes’s perspective the volume is deleted.
Persistent Volumes API resource solves this problem where PVs have lifecycle independent of the Pods and not created when Pod is spawned. PVs are units of storage provisioned in advance, they are Kubernetes objects backed by a persistent storage.
PVs are created, deleted using kubectl commands.

In order to use these PVs user needs to create PersistentVolumeClaims which is nothing but a request for PVs. A claim must specify the access mode and storage capacity, once a claim is created PV is automatically bound to this claim. Kubernetes will bind a PV to PVC based on access mode and storage capacity but claim can also mention volume name

Recommended reading:
* https://github.com/kubernetes-incubator/external-storage/tree/master/aws/efs


## Prerequisites
* An EFS file system in your cluster's region
* [Mount targets](http://docs.aws.amazon.com/efs/latest/ug/accessing-fs.html) and [security groups](http://docs.aws.amazon.com/efs/latest/ug/accessing-fs-create-security-groups.html) such that any node (in any zone in the cluster's region) can mount the EFS file system by its [File system DNS name](http://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-cmd-dns-name.html)
* [EFS Profisioner Helm Chart](https://github.com/helm/charts/tree/master/stable/efs-provisioner)


### Installing EFS Provisioner using the Helm Chart

Edit the values.yaml file and change __efsFileSystemId__ and __awsRegion__ with your filesystemid and AWS Region and run the command bellow:

```bash
helm install stable/efs-provisioner --name efs-provisioner -f values.yaml --namespace=<desired-namespace>
```

# Create the PVC

```bash
kubectl apply -f pvc.yaml -n <desired-namespace>
```

# Test by running a pod

```bash
kubectl apply -f efs-pod.yaml
```
