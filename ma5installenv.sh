#!/bin/bash

if [ $# != 6 ]
  then 
  echo "This script needs 6 arguments/variables to run; ELB-NAME, KEYPAIR, CLIENT-TOKEN 1, ClIENT-TOKEN 2, NUMBER OF INSTANCES, and SECURITY-GROUP-NAME"
else

#Step 1:
VPCID=(`aws ec2 create-vpc --cidr-block 10.0.0.0/24 --output=text | awk {'print $6'}`); echo $VPCID
    
    
##Step 2:
SUBNETID=(`aws ec2 create-subnet --vpc-id $VPCID --cidr-block 10.0.0.0/25 --availability-zone us-east-1b --output=text | awk {'print $6'}`); echo $SUBNETID 
# second subnet for RDS group
SUBNETID2=(`aws ec2 create-subnet --vpc-id $VPCID --cidr-block 10.0.0.128/25 --availability-zone us-east-1c --output=text | awk {'print $6'}`); echo $SUBNETID2

#Create Database Subnet group -- requires two AZs
DBSUBNETID=(`aws rds create-db-subnet-group --db-subnet-group-name Ma5FinalProjectBackend --db-subnet-group-description "Ma5FinalProject" --db-subnet-list $SUBNETID,$SUBNETID2`)




#Step 3:  Find id of the VPC just created security group
SGID=(`aws ec2 create-security-group --group-name $6 --description "itmo544-444 MA4 allows 80 and 3306 and 22 TCP" --vpc-id $VPCID --output=text | awk {'print $1'} `); echo $SGID

#step 3b: For SSH and WEB
aws ec2 authorize-security-group-ingress --group-id $SGID --protocol tcp --port 80 --cidr 0.0.0.0/0 
aws ec2 authorize-security-group-ingress --group-id $SGID --protocol tcp --port 22 --cidr 0.0.0.0/0 
aws ec2 authorize-security-group-ingress --group-id $SGID --protocol tcp --port 3306 --cidr 0.0.0.0/0 



#Step 4: 
GATEWAY=(`aws ec2 create-internet-gateway --output=text | awk {'print $2'}`); echo $GATEWAY

#step 4b:
aws ec2 modify-vpc-attribute --vpc-id $VPCID --enable-dns-support "{\"Value\":true}" --output=text
aws ec2 modify-vpc-attribute --vpc-id $VPCID --enable-dns-hostnames "{\"Value\":true}" --output=text

#Step 5 
aws ec2 modify-subnet-attribute --subnet $SUBNETID --map-public-ip-on-launch --output=text 

#Step 6
aws ec2 attach-internet-gateway --internet-gateway-id $GATEWAY --vpc-id $VPCID --output=text 

#Step 6b
ROUTETABLE=(`aws ec2 create-route-table --vpc-id $VPCID --output=text | grep rtb | awk {'print $2'}`)

#Step 6c
aws ec2 create-route --route-table-id $ROUTETABLE --destination-cidr-block 0.0.0.0/0 --gateway-id $GATEWAY --output=text
aws ec2 associate-route-table --route-table-id $ROUTETABLE --subnet-id $SUBNETID --output=text

#Step 7 
ELBURL=(`aws elb create-load-balancer --load-balancer-name $1 --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $SUBNETID --security-groups $SGID --output=text`); echo $ELBURL
echo -e "\nFinished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#step 7b:
aws elb configure-health-check --load-balancer-name $1 --health-check Target=HTTP:80/index.html,Interval=30,Timeout=5,UnhealthyThreshold=2,HealthyThreshold=10
#sleep 30 
echo -e "\nFinished ELB health check and sleeping 30 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Step 8: (create instance group one)
aws ec2 run-instances --image-id ami-e84d8480 --count $5 --instance-type t1.micro --key-name $2 --security-group-ids $SGID --subnet-id $SUBNETID --client-token $3 --iam-instance-profile Name=iamaccess --user-data file://setup-MA3.sh --output=table
echo -e "\nFinished launching EC2 Instances and sleeping 60 seconds"
for i in {0..60}; do echo -ne '.'; sleep 1;done

#Step 9:
declare -a ARRAY 
ARRAY=(`aws ec2 describe-instances --filters Name=client-token,Values=$3 --output text | grep INSTANCES | awk {' print $8'}`)
echo -e "\nListing Instances, filtering their instance-id, adding them to an ARRAY and sleeping 15 seconds"
for i in {0..15}; do echo -ne '.'; sleep 1;done

#Step 10: (register instances with load balancer and create tags for instances)
LENGTH=${#ARRAY[@]}
echo "ARRAY LENGTH IS $LENGTH"
for (( i=0; i<${LENGTH}; i++)); 
  do
  echo "Registering ${ARRAY[$i]} with load-balancer $1" 
  aws elb register-instances-with-load-balancer --load-balancer-name $1 --instances ${ARRAY[$i]} --output=table 
aws ec2 create-tags --resources ${ARRAY[$i]} --tags Key=Name,Value=MA5ImageSubmitInstances	
echo -e "\nLooping through instance array and registering each instance one at a time with the load-balancer.  Then sleeping 60 seconds to allow the process to finish. )"
    for y in {0..60} 
    do
      echo -ne '.'
      sleep 1
    done
 echo "\n"
done

echo -e "\nWaiting an additional 3 minutes (180 second) - before opening the ELB in a webbrowser"
for i in {0..180}; do echo -ne '.'; sleep 1;done

#Step ll (create database):
aws rds create-db-instance --db-name ma5ImageStore --db-instance-identifier ma5FinalProject --allocated-storage 10 --db-instance-class db.t1.micro --engine MySQL --master-username dkuser --master-user-password sWaJama3ha5AdR --db-subnet-group-name $DBSUBNETID --output=text 

#Step 12 (create SES queue):
aws sqs create-queue --queue-name ma5queue --output=text

#Step 13 (create SNS topic)
aws sns create-topic --name ma5notification

#Step 15 (launch 2nd instance group)
aws ec2 run-instances --image-id ami-e84d8480 --count 1 --instance-type t1.micro --key-name $2 --security-group-ids $SGID --subnet-id $SUBNETID --client-token $4 --iam-instance-profile Name=iamaccess --user-data file://newma.sh --output=table
echo -e "\nFinished launching EC2 Instances and sleeping 60 seconds"
for i in {0..60}; do echo -ne '.'; sleep 1;done

#step 16 (describe instance and put in array)
declare -a ARRAY2 
ARRAY2=(`aws ec2 describe-instances --filters Name=client-token,Values=$4 --output text | grep INSTANCES | awk {' print $8'}`)
echo -e "\nListing Instances, filtering their instance-id, adding them to an ARRAY and sleeping 15 seconds"
for i in {0..15}; do echo -ne '.'; sleep 1;done

#step 17 (add tags to instance)
LENGTH=${#ARRAY2[@]}
echo "ARRAY LENGTH IS $LENGTH"
for (( i=0; i<${LENGTH}; i++)); 
  do
  echo "Tagging ${ARRAY2[$i]}" 
aws ec2 create-tags --resources ${ARRAY2[$i]} --tags Key=Name,Value=MA5ImageModInstance	
done

#Last Step
#firefox $ELBURL &
chromium-browser $ELBURL & 
EXPORT $ELBURL

fi  #End of if statement
