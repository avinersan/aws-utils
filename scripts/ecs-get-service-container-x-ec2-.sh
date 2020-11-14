#!/usr/bin/env bash

# requires 
# - jq https://stedolan.github.io/jq/download/ (use a package manager - brew install jq)
# - aws cli - https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

# example
# ./ecs-get-service-container-x-ec2-.sh

SERVICE_NAME=$1
CLUSTER_NAME=prd
CONTAINER_NAME=app

TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME | jq -r '.taskArns | map(.) |  join(" ")')
TASKS=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARNS)

# EC2xCONTAINER_ID=$(echo $TASKS | jq '[.tasks[] | { ec2Arn: .containerInstanceArn, containerId: .containers[].runtimeId, containerName: .containers[].name } ] | map(select(.containerName == "'$CONTAINER_NAME'" ))')
EC2xCONTAINER_ID=$(echo $TASKS | jq '[
   .tasks[] | 
   { ec2Arn: .containerInstanceArn, containers: .containers | 
   map({name: .name, id: .runtimeId }) } | 
   { ec2Arn: .ec2Arn} + .containers[] | 
   select(.name == "app") ]')
EC2_ARNS=$(echo $EC2xCONTAINER_ID | jq -r '[.[] | .ec2Arn ] | join(" ")')
EC2_CONTAINERS=$(aws ecs describe-container-instances --cluster $CLUSTER_NAME --container-instances $EC2_ARNS | jq '
  [ 
    .containerInstances[] 
    | { ec2InstanceId: .ec2InstanceId, ec2Arn: .containerInstanceArn  } 
  ]')

(echo $EC2xCONTAINER_ID; echo $EC2_CONTAINERS) | jq -sr '
 flatten 
 | group_by(.ec2Arn) 
 | map(reduce .[] as $x ({}; . * $x))
 | (.[0] | keys_unsorted | @tsv), (.[] | . | map(.) | @tsv )
 ' | column -t
