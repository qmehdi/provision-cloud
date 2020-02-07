variable "Env" {}
variable "SecondOctet" {}
variable "ClusterName" {}
variable "aws_region" {}

variable "region_ami" {
  type = map

  default = {
    us-east-1 = "ami-087a82f6b78a07557"
    us-east-2 = "ami-080fbb09ee2d4d3fa"
    us-west-1 = "ami-047934c0ddfe7eb47"
    us-west-2 = "ami-0c13bb9cbfd007e56"
  }
}

#aurora
variable "db_name" {}
variable "db_user" {}
variable "db_password" {}
variable "db_port"  {}

#gov stuff
variable "provider_db_host" {}
variable "provider_db_port" {}
variable "provider_db_name" {}
variable "provider_db_user" {}
variable "provider_db_password" {}
variable "claims_data_s3_path" {}

terraform {
  required_version = ">= 0.12.18"
}

provider "aws" {
  region = "${var.aws_region}"
}
#files generated from a terraform run will be stored in this dir
# resource "null_resource" "create_files_dir" {
#   provisioner "local-exec" {
#     command = "mkdir ./files"
#   }
# }

# Create the vpc
resource "aws_cloudformation_stack" "eks-vpc" {
  name = "${var.Env}-vpc"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    Env = "${var.Env}",
    SecondOctet = "${var.SecondOctet}"
    ClusterName = "${var.ClusterName}"
  }
  template_body = file("${path.module}/../cloudformation/network/vpc.yaml")
}

# Create the eks master service
resource "aws_cloudformation_stack" "eks-master" {
  name = "${var.Env}-eks-master"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    ClusterVersion = "1.14"
    Env = "${var.Env}"
    ClusterName = "${var.ClusterName}"
  }
  template_body = "${file("${path.module}/../cloudformation/compute/eks-master.yaml")}"

  depends_on = ["aws_cloudformation_stack.eks-vpc"]
}

output "ClusterEndpoint" {
  value = "${aws_cloudformation_stack.eks-master.outputs["ClusterEndpoint"]}"
}

output "ClusterControlPlaneSecurityGroup" {
  value = "${aws_cloudformation_stack.eks-master.outputs["ClusterControlPlaneSecurityGroup"]}"
}

# # Create key pair for nodes
# resource "aws_key_pair" "eks-key-pair" {
#   key_name = "${var.Env}-ssh-key"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDCIDR0lR6cBRZtT12OjIqCU4WKBpuSrUakPknh9hUINu15sM954Snjsf8qFVkM1ntXyb1hpRNDlAU8lOTKmbMToDVoETp2bsmhVqEjeRgTkaelus8RHIBzO70sd6ZsuUMi8ovcx7MiTJ1i6VLaYdprJmRINMwmbmBEFTIWMme2X5hvBXm/phAYdEVgcQxl1Sq7LyK8DyEdtIZ7VlvfD8f+dhbiJweQOEu9OcuIKJgCCg1nDshAJP/m/hTbgXvunLlqBAA+N03s5t1Jtz9dYRbaHxmn/77uDt8HwsvGhPGFSlXpKXyY1F1z7tLVnLThKftCMa/G9i7irlr/04o+BKZakzyY8sqUo9xVM8bB7z4r7Y1j8VhVzPzTSbljAxsBKzq9JqT511FfU9YkCKa7OhkjsBWcCfk6eFPaytYyqRvQIhDtrD1lBuLgF7mPVLzuub82vkCk7RrT9sTOXbkBHtlzTB1aHE2AUqxSsaMgcXvbQfnh0yGTJC4I1K2OBSkBpjm3lqAfMJIHR2M/sW74RWZ+HNLbtGXea10/VoKmS8hV5PtZa1rISDW6uOW+Kb5bW6rkXv5yFyShABKTco7we9bzc0hFCPXa8NFVtTEb3/O4T3/mjunp6h4UTWOR8PgQPdMjtHmEBwmIezK/iRTA9MiL6McSdV2KBhZ+RcLCpY2ixQ== qambermehdi@Qambers-MacBook-Pro.local"
# }

# Create API Gateway
resource "aws_cloudformation_stack" "api-gateway" {
  name = "${var.ClusterName}-api-gateway"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    ClusterName = "${var.ClusterName}",
    Env = "${var.Env}",
  }
  template_body = file("${path.module}/../cloudformation/compute/api-gateway.yaml")

  depends_on = ["aws_cloudformation_stack.eks-vpc"]
}

output "DatabaseClusterReadEndpoint" {
  value = "${aws_cloudformation_stack.postgres.outputs["DatabaseClusterReadEndpoint"]}"
}

output "RDSDBEndpoint" {
  value = "${aws_cloudformation_stack.postgres.outputs["RDSDBEndpoint"]}"
}

# Create eks workers
resource "aws_cloudformation_stack" "eks-workers" {
  name = "${var.ClusterName}-workers"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    ClusterName = "${var.ClusterName}",
    BootstrapArguments = "--kubelet-extra-args '--eviction-soft=memory.available<20% --eviction-soft-grace-period=memory.available=1m --eviction-max-pod-grace-period=30 --eviction-minimum-reclaim=memory.available=8% --eviction-pressure-transition-period=10m --node-labels=nodePurpose=${var.ClusterName}-workers'",
    Env = "${var.Env}",
    NodeAutoScalingGroupDesiredCapacity = 1,
    NodeAutoScalingGroupMaxSize = 5,
    NodeAutoScalingGroupMinSize	= 0,
    NodeGroupName	= "${var.ClusterName}-workers",
    NodeImageId	= "${var.region_ami["${var.aws_region}"]}",
    NodeInstanceType = "m5.large",
  }
  template_body = "${file("${path.module}/../cloudformation/compute/eks-workers.yaml")}"

  depends_on = ["aws_cloudformation_stack.eks-master", "aws_cloudformation_stack.api-gateway"]

  provisioner "local-exec" {
    command = "helm del --purge nginx --kubeconfig ${path.module}/files/kubeconfig.yaml || true"
    when = "destroy"
  }
}

# Create eks workers
resource "aws_cloudformation_stack" "postgres" {
  name = "${var.Env}-aurora-psql"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    #Need to look up better way to make this variable reference eks-master name variable
    Env = "${var.Env}",
    DBName = "${var.db_name}", #name of cloudformation stack
    DBUser = "${var.db_user}",
    DBPassword = "${var.db_password}",
    DBInstanceClass = "db.t2.small",
  }
  template_body = "${file("${path.module}/../cloudformation/database/postgres.yaml")}"

  depends_on = ["aws_cloudformation_stack.eks-vpc"]
}

output "ApiId" {
  value = "https://${aws_cloudformation_stack.api-gateway.outputs["ApiId"]}.execute-api.${var.aws_region}.amazonaws.com/dev/"
}
#########################################################
# export the EKS cluster KUBECONFIG into the eks-kubeconfigs dir
resource "null_resource" "get-kube-config" {
  provisioner "local-exec" {
    working_dir = "${path.module}"
    command = <<SCRIPT
max_retry=20
counter=0
echo "Trying to obtain kubeconfig..."
aws eks update-kubeconfig --region ${var.aws_region} --name ${var.ClusterName} --kubeconfig ./files/kubeconfig.yaml || true
until [ -f ./files/kubeconfig.yaml ]
do
    aws eks update-kubeconfig --region ${var.aws_region} --name ${var.ClusterName} --kubeconfig ./files/kubeconfig.yaml
    [[ counter -eq $max_retry ]] && echo "Failed to retrieve kubeconfig" && exit 1
    echo "Sleep 15 then trying again. Attempt #$counter"
    sleep 15
    ((counter++))
done
echo "Obtained config"

max_retry=30
counter=0
echo "Validating kubectl can connect to cluster"
until [ $(kubectl get deploy/coredns -n kube-system --kubeconfig ./files/kubeconfig.yaml | grep -o coredns) == "coredns" ]
do
  [[ counter -eq $max_retry ]] && echo "Timed out!" && exit 1
  echo "Failed to connect, sleep 15 try again"
  sleep 15
  ((counter++))
done
echo "Kubectl connected"
SCRIPT
  }
  depends_on = ["aws_cloudformation_stack.eks-master"]
}


#############################################################
# Create configmap to allow nodes to connect to eks master and give other DevOps people admin access
locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: aws-auth
    namespace: kube-system
  data:
    mapRoles: |
      - rolearn:  ${aws_cloudformation_stack.eks-master.outputs["NodeInstanceRole"]}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
          - system:masters
CONFIGMAPAWSAUTH
}

# Store the configmap from above into a file
resource "local_file" "config_map_aws_auth" {
    content = "${local.config_map_aws_auth}"
    filename = "${path.module}/files/${var.ClusterName}-config_map_aws_auth.yaml"
    depends_on = ["null_resource.get-kube-config"]
}

# apply auth map to enable eks-workers to join eks-master
resource "null_resource" "create-config_map_aws_auth" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/${var.ClusterName}-config_map_aws_auth.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["local_file.config_map_aws_auth", "null_resource.get-kube-config"]
}
#The api key
resource "null_resource" "display_api_key_value" {
  provisioner "local-exec" {
    command = "aws apigateway get-api-keys --query 'items[?name==`${var.Env}-Api-Key`].value' --include-values --output text --region ${var.aws_region} > ./files/api_key.txt"
  }
  depends_on = ["aws_cloudformation_stack.api-gateway"]
}

#The API Gateway Endpoint
resource "null_resource" "display_api_gateway_url" {
  provisioner "local-exec" {
    command = "echo https://${aws_cloudformation_stack.api-gateway.outputs["ApiId"]}.execute-api.${var.aws_region}.amazonaws.com/dev/ > ./files/api_gateway_url.txt"
  }
  depends_on = ["aws_cloudformation_stack.api-gateway"]
}

# Create NLB Ingress
locals {
  nlb_ingress = <<NLBINGRESS
  apiVersion: extensions/v1beta1
  kind: Ingress
  metadata:
    name: nlb-ingress
    annotations:
      kubernetes.io/ingress.class: nginx-ingress
  spec:
    rules:
    - host:  ${aws_cloudformation_stack.api-gateway.outputs["NLBDNSName"]}
      http:
        paths:
        - backend:
            serviceName: fhir-service
            servicePort: 8080

NLBINGRESS
}

resource "local_file" "nlb_ingress" {
  content = "${local.nlb_ingress}"
  filename = "${path.module}/files/nlb_ingress.yaml"
  depends_on = ["null_resource.get-kube-config", "aws_cloudformation_stack.api-gateway"]
}

#This is needed to route api gateway calls to the fhir service
resource "null_resource" "create_nlb_ingress" {
  provisioner "local-exec" {
    command = "kubectl apply -n default -f ${path.module}/files/nlb_ingress.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["local_file.nlb_ingress", "null_resource.get-kube-config"]
}

#Tiller is needed to be able to deploy helm charts
resource "null_resource" "apply_tiller_stuff" {
  provisioner "local-exec" {
    command = "kubectl apply -f ../../tiller/rbac-tiller.yaml && kubectl apply -f ../../tiller/rbac-config.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.create-config_map_aws_auth", "null_resource.get-kube-config"]
}

#Install Helm
resource "null_resource" "install_helm" {
  provisioner "local-exec" {
    command = "helm init"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.apply_tiller_stuff", "null_resource.get-kube-config"]
}

resource "null_resource" "sleep" {
  provisioner "local-exec" {
    command = "sleep 65"
  }
  depends_on = ["null_resource.install_helm"]
}

#This is needed to do helm deployments via tiller
resource "null_resource" "patch_tiller" {
  provisioner "local-exec" {
    command = "../../tiller/patch-tiller.sh"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.sleep", "null_resource.get-kube-config"]
}

resource "null_resource" "sleep2" {
  provisioner "local-exec" {
    command = "sleep 120"
  }
  depends_on = ["null_resource.install_helm"]
}

#This is needed to do helm deploys
resource "null_resource" "clusterrolebinding" {
  provisioner "local-exec" {
    command = "kubectl create clusterrolebinding kube-system-default-crbinding --clusterrole cluster-admin --serviceaccount=kube-system:default"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.sleep2", "null_resource.get-kube-config"]
}

#NGINX is needed to route requests to the service from the NLB
resource "null_resource" "install_nginx" {
  provisioner "local-exec" {
    command = "../../nginx/deploy-nginx.sh"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}

# resource "null_resource" "create_regcred_secret" {
#   provisioner "local-exec" {
#     command = "kubectl apply -f ../../kube-manifests/regcred.yaml"
#
#     environment = {
#       KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
#     }
#   }
#   depends_on = ["null_resource.clusterrolebinding"]
# }

##### Deploy secret for FHIR service ######
#Generate fhir-secret yaml
locals {
  fhir_secret = <<FHIRSECRET
  apiVersion: v1
  kind: Secret
  metadata:
    name: fhir-secret
  type: Opaque
  stringData:
    DB_HOST: "${aws_cloudformation_stack.postgres.outputs["DatabaseClusterReadEndpoint"]}"
    DB_PORT: "${var.db_port}"
    DB_NAME: "${var.db_name}"
    DB_USER: "${var.db_user}"
    DB_PASSWORD: "${var.db_password}"
    APP_URL: "https://${aws_cloudformation_stack.api-gateway.outputs["ApiId"]}.execute-api.${var.aws_region}.amazonaws.com/dev"
FHIRSECRET
}

# Store the secret from above into a file
resource "local_file" "fhir_secret" {
    content = "${local.fhir_secret}"
    filename = "${path.module}/files/${var.ClusterName}-fhir-secret.yaml"
    depends_on = ["null_resource.get-kube-config"]
}

# apply and create the fhir-secret
resource "null_resource" "create_fhir_secret" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/${var.ClusterName}-fhir-secret.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["local_file.fhir_secret", "null_resource.get-kube-config"]
}

##### Deploy fhir service and deployment manifests #####
resource "null_resource" "deploy_fhir" {
  provisioner "local-exec" {
    command = "kubectl apply -f ../../kube-manifests/deployment.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.clusterrolebinding", "null_resource.create_fhir_secret", "null_resource.get-kube-config"]
}
#######################
##### Deploy ETL ######
#Generate etl-secret yaml
locals {
  etl_secret = <<ETLSECRET
  apiVersion: v1
  kind: Secret
  metadata:
    name: etl-secret
  type: Opaque
  stringData:
    DB_HOST: "${aws_cloudformation_stack.postgres.outputs["RDSDBEndpoint"]}"
    DB_PORT: "${var.db_port}"
    DB_NAME: "${var.db_name}"
    DB_USER: "${var.db_user}"
    DB_PASSWORD: "${var.db_password}"
    PROVIDER_DB_HOST: "${var.provider_db_host}"
    PROVIDER_DB_PORT: "${var.provider_db_port}"
    PROVIDER_DB_NAME: "${var.provider_db_name}"
    PROVIDER_DB_USER: "${var.provider_db_user}"
    PROVIDER_DB_PASSWORD: "${var.provider_db_password}"
    CLAIMS_DATA_S3_PATH: "${var.claims_data_s3_path}"
ETLSECRET
}

# Store the secret from above into a file
resource "local_file" "etl_secret" {
    content = "${local.etl_secret}"
    filename = "${path.module}/files/${var.ClusterName}-etl-secret.yaml"
    depends_on = ["null_resource.get-kube-config"]
}

# apply and create the etl-secret
resource "null_resource" "create_etl_secret" {
  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/files/${var.ClusterName}-etl-secret.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["local_file.etl_secret", "null_resource.get-kube-config"]
}

##### Deploy etl service and deployment manifests #####
resource "null_resource" "deploy_etl" {
  provisioner "local-exec" {
    command = "kubectl apply -f ../../kube-manifests/etl_deployment.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.clusterrolebinding", "null_resource.create_etl_secret", "null_resource.get-kube-config"]
}

##########End of ETL######
