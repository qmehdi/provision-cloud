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

terraform {
  required_version = ">= 0.12.20"
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

# Create eks workers
resource "aws_cloudformation_stack" "eks-workers" {
  name = "${var.ClusterName}-workers"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    #KeyName = "cam"
    ClusterName = "${var.ClusterName}",
    BootstrapArguments = "--enable-docker-bridge true --kubelet-extra-args '--eviction-soft=memory.available<20% --eviction-soft-grace-period=memory.available=1m --eviction-max-pod-grace-period=30 --eviction-minimum-reclaim=memory.available=8% --eviction-pressure-transition-period=10m --node-labels=nodePurpose=${var.ClusterName}-workers'",
    Env = "${var.Env}",
    NodeAutoScalingGroupDesiredCapacity = 2,
    NodeAutoScalingGroupMaxSize = 5,
    NodeAutoScalingGroupMinSize	= 0,
    NodeGroupName	= "${var.ClusterName}-workers",
    NodeImageId	= "${var.region_ami["${var.aws_region}"]}",
    NodeInstanceType = "m5.large",
  }
  template_body = "${file("${path.module}/../cloudformation/compute/eks-workers.yaml")}"

  depends_on = ["aws_cloudformation_stack.eks-master"]

# Delete NGINX Helm chart on terraform destroy. This must be done first otherwise vpc deletion will fail
  provisioner "local-exec" {
    command = "helm uninstall -n kube-system nginx --kubeconfig ${path.module}/files/kubeconfig.yaml || true"
    when = "destroy"
  }
}

# Create EFS filesystem
resource "aws_cloudformation_stack" "efs-filesystem" {
  name = "${var.ClusterName}-EFS"
  capabilities = ["CAPABILITY_IAM"]
  parameters = {
    Env = "${var.Env}",
    VolumeName = "${var.ClusterName}"
    ClusterName = "${var.ClusterName}"
  }
  template_body = "${file("${path.module}/../cloudformation/storage/efs.yaml")}"

  depends_on = ["aws_cloudformation_stack.eks-master", "aws_cloudformation_stack.eks-vpc"]
}

output "FileSystemID" {
  value = "${aws_cloudformation_stack.efs-filesystem.outputs["FileSystemID"]}"
}

# Create eks workers
# resource "aws_cloudformation_stack" "postgres" {
#   name = "${var.Env}-aurora-psql"
#   capabilities = ["CAPABILITY_IAM"]
#   parameters = {
#     #Need to look up better way to make this variable reference eks-master name variable
#     Env = "${var.Env}",
#     DBName = "${var.db_name}", #name of cloudformation stack
#     DBUser = "${var.db_user}",
#     DBPassword = "${var.db_password}",
#     DBInstanceClass = "db.t2.small",
#   }
#   template_body = "${file("${path.module}/../cloudformation/database/postgres.yaml")}"
#
#   depends_on = ["aws_cloudformation_stack.eks-vpc"]
# }
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

resource "null_resource" "sleep2" {
  provisioner "local-exec" {
    command = "sleep 10"
  }
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

# Deploy efs-provisioner helm chart 
resource "null_resource" "deploy_efs-provisioner" {
  provisioner "local-exec" {
    command = "../../helm-services/efs-provisioner/deploy-efs-provisioner.sh ${aws_cloudformation_stack.efs-filesystem.outputs["FileSystemID"]}"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["aws_cloudformation_stack.efs-filesystem", "null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}

# Create jenkins namespace
resource "null_resource" "create_jenkins_ns" {
  provisioner "local-exec" {
    command = "kubectl create ns jenkins"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}

#Deploy External DNS
resource "null_resource" "deploy_external_dns" {
  provisioner "local-exec" {
    command = "../../helm-services/external-dns/deploy-external-dns.sh"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}

#Deploy PVC
resource "null_resource" "install_pvc" {
  provisioner "local-exec" {
    command = "kubectl apply -n jenkins -f ../../helm-services/efs-provisioner/pvc.yaml"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.deploy_external_dns", "null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}


#Deploy NGINX
resource "null_resource" "install_nginx" {
  provisioner "local-exec" {
    command = "../../helm-services/nginx/deploy-nginx.sh"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.deploy_external_dns", "null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}

#Deploy Jenkins 
resource "null_resource" "deploy_jenkins" {
  provisioner "local-exec" {
    command = "../../helm-services/jenkins/deploy-jenkins.sh"

    environment = {
      KUBECONFIG = "${path.module}/files/kubeconfig.yaml"
    }
  }
  depends_on = ["null_resource.deploy_external_dns", "null_resource.sleep2", "null_resource.clusterrolebinding", "null_resource.get-kube-config"]
}

