# Spinnaker Chart

[Spinnaker](http://spinnaker.io/) is an open source, multi-cloud continuous delivery platform.

## Chart Details
This chart will provision a fully functional and fully featured Spinnaker installation
that can deploy and manage applications in the cluster that it is deployed to.

Redis and Minio are used as the stores for Spinnaker state.

For more information on Spinnaker and its capabilities, see it's [documentation](http://www.spinnaker.io/docs).

## Installing the Chart

Before intalling the chart, make sure you have the cluster clean from other installations by running:

```bash
  kubectl delete job -n spinnaker spinnaker-install-using-hal spinnaker-spinnaker-cleanup-using-hal
    kubectl delete pvc -n spinnaker --force --grace-period=0 halyard-home-spinnaker-spinnaker-halyard-0
```

To install the chart with the release name `spinnaker`:

Do the following steps before running the helm install command:
0 - kubectl create ns spinnaker
1 - kubectl create secret generic dev-ecr-secret -n spinnaker --from-literal=dev-ecr=$(aws ecr get-login --region us-east-1 --no-include-email | cut -d ' ' -f 6)
  3 - kubectl create secret generic --from-file=./spinnaker-kubeconfig.yaml spinnaker-kubeconfig -n spinnaker

  curl -vvv -L -H 'Content-Type: application/json' -X POST -d '{"parameters":{"skipJudgement":"true","tag":"0.0.249","createSecrets":"true","publishAPI":"false"},"artifacts":[{"type":"s3/object","name":"s3://dais-helm-charts/packagevalues/file-ingestion-entrypoint:/values.yaml","reference":"s3://dais-helm-charts/packagevalues/file-ingestion-entrypoint:/values-0.0.249.yaml"}]}' https://spinnaker.dais.com:8084/webhooks/webhook/file-ingestion-entrypoint-deploy-to-uat


curl -vvv -L -H 'Content-Type: application/json' -X POST -d '{"artifacts":[{"type":"s3/object","name":"s3://fhir-helm-charts/values.yaml","reference":"s3://fhir-helm-charts/values.yaml"}]}' \
http://gate.fhir.semanticbits.com/webhooks/webhook/deploy2-impl



```bash
helm install --name spinnaker . --timeout 600 --namespace spinnaker -f values.yaml --debug &
```

To Upgrade:

```bash
helm upgrade spinnaker -f values.yaml .
```

Note that this chart pulls in many different Docker images so can take a while to fully install.

## Configuration

Configurable values are documented in the `values.yaml`.

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example,


~~$ helm install --name spinnaker -f values.yaml stable/spinnaker~~


> **Tip**: You can use the default [values.yaml](values.yaml)

## Adding Kubernetes Clusters to Spinnaker

By default, installing the chart only registers the local cluster as a deploy target
for Spinnaker. If you want to add arbitrary clusters need to do the following:

1. Upload your kubeconfig to a secret with the key `config` in the cluster you are installing Spinnaker to.

```shell
$ kubectl create secret generic --from-file=./spinnaker-kubeconfig.yaml spinnaker-kubeconfig -n spinnaker
```

1. Set the following values of the chart:

```yaml
kubeConfig:
  enabled: true
  secretName: my-kubeconfig
  secretKey: config
  contexts:
  # Names of contexts available in the uploaded kubeconfig
  - my-context
  # This is the context from the list above that you would like
  # to deploy Spinnaker itself to.
  deploymentContext: my-context
```

## Specifying Docker Registries and Valid Images (Repositories)

Spinnaker will only give you access to Docker images that have been whitelisted, if you're using a private registry or a private repository you also need to provide credentials.  Update the following values of the chart to do so:

```yaml
dockerRegistries:
- name: dockerhub
  address: index.docker.io
  repositories:
    - library/alpine
    - library/ubuntu
    - library/centos
    - library/nginx
# - name: gcr
#   address: https://gcr.io
#   username: _json_key
#   password: '<INSERT YOUR SERVICE ACCOUNT JSON HERE>'
#   email: 1234@5678.com
```

You can provide passwords as a Helm value, or you can use a pre-created secret containing your registry passwords.  The secret should have an item per Registry in the format: `<registry name>: <password>`. In which case you'll specify the secret to use in `dockerRegistryAccountSecret` like so:

```yaml
dockerRegistryAccountSecret: myregistry-secrets
```

Adding an ECR registry:

```shell
echo  $(aws ecr get-authorization-token --region us-west-2 --output text --query 'authorizationData[].authorizationToken' | base64 --decode | cut -d: -f2) > dev-ecr
kubectl create secret generic --from-file=./dev-ecr dev-ecr-secret -n spinnaker
```

Under dockerRegistries add:

```yaml
- name: dev-ecr
  address: 991853876083.dkr.ecr.us-west-2.amazonaws.com
  username: AWS
```

Set dockerRegistryAccountSecret as follows:

```yaml
dockerRegistryAccountSecret: dev-ecr-secret
```

## Specifying persistent storage

Spinnaker supports [many](https://www.spinnaker.io/setup/install/storage/) persistent storage types. Currently, this chart supports the following:

* Azure Storage
* Google Cloud Storage
* Minio (local S3-compatible object store)
* Redis
* AWS S3

## Customizing your installation

### Manual
While the default installation is ready to handle your Kubernetes deployments, there are
many different integrations that you can turn on with Spinnaker. In order to customize
Spinnaker, you can use the [Halyard](https://www.spinnaker.io/reference/halyard/) command line `hal`
to edit the configuration and apply it to what has already been deployed.

Halyard has an in-cluster daemon that stores your configuration. You can exec a shell in this pod to
make and apply your changes. The Halyard daemon is configured with a persistent volume to ensure that
your configuration data persists any node failures, reboots or upgrades.

For example:

```shell
$ helm install -n cd stable/spinnaker
$ kubectl exec -it cd-spinnaker-halyard-0 bash
spinnaker@cd-spinnaker-halyard-0:/workdir$ hal version list
```

### Automated
If you have known set of commands that you'd like to run after the base config steps or if
you'd like to override some settings before the Spinnaker deployment is applied, you can enable
the `halyard.additionalScripts.enabled` flag. You will need to create a config map that contains a key
containing the `hal` commands you'd like to run. You can set the key via the config map name via `halyard.additionalScripts.configMapName` and the key via `halyard.additionalScripts.configMapKey`. The `DAEMON_ENDPOINT` environment variable can be used in your custom commands to
get a prepopulated URL that points to your Halyard daemon within the cluster. The `HAL_COMMAND` environment variable does this for you. For example:

```shell
hal --daemon-endpoint $DAEMON_ENDPOINT config security authn oauth2 enable
$HAL_COMMAND config security authn oauth2 enable
```

If you would rather the chart make the config file for you, you can set `halyard.additionalScripts.create` to `true` and then populate `halyard.additionalScripts.data.SCRIPT_NAME.sh` with the bash script you'd like to run. If you need associated configmaps or secrets you can configure those to be created as well:

```yaml
halyard:
  additionalScripts:
    create: true
    data:
      enable_oauth.sh: |-
        echo "Setting oauth2 security"
        $HAL_COMMAND config security authn oauth2 enable
  additionalSecrets:
    create: true
    data:
      password.txt: aHVudGVyMgo=
  additionalConfigMaps:
    create: true
    data:
      metadata.xml: <xml><username>admin</username></xml>
  additionalProfileConfigMaps:
    create: true
    data:
      orca-local.yml: |-
        tasks:
          useManagedServiceAccounts: true
```

Any files added through `additionalConfigMaps` will be written to disk at `/opt/halyard/additionalConfigMaps`.

### Set custom annotations for the halyard pod

```yaml
halyard:
  annotations:
    iam.amazonaws.com/role: <role_arn>
```

### Set environment variables on the halyard pod

```yaml
halyard:
  env:
    - name: DEFAULT_JVM_OPTS
      value: -Dhttp.proxyHost=proxy.example.com
```
