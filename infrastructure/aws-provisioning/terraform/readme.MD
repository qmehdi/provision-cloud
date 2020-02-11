
#Using terraform version v0.12.5
terraform init

terraform plan -var 'Env=cam' -var 'SecondOctet=50' -var 'ClusterName=pandora'  -var 'aws_region=us-east-1'

terraform apply -var 'Env=cam' -var 'SecondOctet=50' -var 'ClusterName=pandora'  -var 'aws_region=us-east-1'  -auto-approve

#To destroy
terraform destroy -var 'Env=cam' -var 'SecondOctet=50' -var 'ClusterName=pandora' -var 'aws_region=us-east-1'  -auto-approve
