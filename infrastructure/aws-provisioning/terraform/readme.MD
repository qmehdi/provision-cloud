
#Using terraform version v0.12.5
terraform init

terraform plan -var 'Env=bb2-test12' -var 'SecondOctet=49' -var 'ClusterName=bb2-test12-eks' -var 'DBName=bb2-test12' -var 'DBUser=superuser' -var 'DBPassword=supersecurepassword' -var 'aws_region=us-east-1' -var 'gov_db_host=hostname' -var 'gov_db_user=dbuser' -var 'gov_db_pw=dbpw' -var 'gov_s3_path=s3path' \

terraform apply -var 'Env=bb2-test12' -var 'SecondOctet=49' -var 'ClusterName=bb2-test12-eks' -var 'DBName=bb2-test12' -var 'DBUser=superuser' -var 'DBPassword=supersecurepassword' -var 'aws_region=us-east-1' -var 'gov_db_host=hostname' -var 'gov_db_user=dbuser' -var 'gov_db_pw=dbpw' -var 'gov_s3_path=s3path' -auto-approve

#To destroy
terraform destroy -var 'Env=bb2-test12' -var 'SecondOctet=49' -var 'ClusterName=bb2-test12-eks' -var 'DBName=bb2-test12' -var 'DBUser=superuser' -var 'DBPassword=supersecurepassword' -var 'aws_region=us-east-1' -var 'gov_db_host=hostname' -var 'gov_db_user=dbuser' -var 'gov_db_pw=dbpw' -var 'gov_s3_path=s3path' -auto-approve
