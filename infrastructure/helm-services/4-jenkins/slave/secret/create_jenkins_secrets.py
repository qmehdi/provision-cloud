import boto3
import json
import yaml
import sys
from company_utils import secret

AWS_REGION='us-west-2'
ASM_MAX_RESULTS=100

asm_client = boto3.client('secretsmanager', AWS_REGION)

def main():
        create_slave_secret('pandora','pandora')

def create_slave_secret(cluster='dev', namespace='dev', secret_name='jenkins-jnlp'):
    namespace = cluster
    jenkins_secrets = get_jenkins_secrets()
    slave_secret = {}
    for s in jenkins_secrets:
        key = s['Name'].split('/')[-1]
        value = asm_client.get_secret_value(SecretId=s['Name'])['SecretString']
        slave_secret[key] = value

    response = secret.replace_namespaced_secret(cluster, namespace, secret_name, slave_secret)        
    if response.status_code == 404:
        response = secret.create_namespaced_secret(cluster, namespace, secret_name, slave_secret)        

def get_jenkins_secrets():
    return list_asm_secrets('devops/jenkins')

def list_asm_secrets(prefix):
    secret_list = []
    #TODO: Get namespace config from dynamodb and call to get the session sts.assume_role()
    # asm_client = session..client('secretsmanager', AWS_REGION)
    response = asm_client.list_secrets(MaxResults=ASM_MAX_RESULTS)
    while add_secrets_from_response(response, secret_list, prefix):
        response = asm_client.list_secrets(MaxResults=ASM_MAX_RESULTS, NextToken=response['NextToken'])
    return secret_list

def add_secrets_from_response(response, secret_list, namespace):
    secret_list.extend(filter_devops_secrets(response['SecretList'], namespace))
    return 'NextToken' in response

# TODO: move this to company_python_packages
# Checks retrieved list if it matches devops/jenkins, adds to a new list called secrets 
def filter_devops_secrets(response_secret_list, prefix):
    filter = prefix + '/'
    secrets = [secret for secret in response_secret_list if filter in secret['Name']]
    return secrets    

if __name__ == "__main__":
    main()