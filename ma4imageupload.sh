#!/bin/bash
# The shell script has a usage pattern provide the data before hand and then reference it.
#example ./sampleinstall.sh jrh544-elb itmo544virtualbox webserverMA3 4 itmo-ma3-group
# In this shell script then value $1  would be the first argument about...jrh544-elb
# $2 would reference the second value itmo544virtualbox and so forth...
if [ $# != 5 ]
  then
  echo "This script needs 5 arguments/variables to run; ELB-NAME, CLIENT-TOKENS, NUMBER OF INSTANCES, SECURITY-GROUP-NAME, and KEYPAIR"
else
#use the aws.amazon.com/cli reference EXTENSIVELY for this - you won't find it via google - hunker down
#Step 1: Create a VPC with a /28 cidr block (see the aws example) - assign the vpc-id to a variable  you can awk column $6 on the --output=text to get the value
vpcid=`aws ec2 create-vpc --cidr-block 10.0.0.0/28 --output=text|awk {'print $6'}`

#Step 2: Create a subnet for the VPC - use the same /28 cidr block that you used in step 1.  Save the subnet-id to a variable (retrieve it by awk column 6)
subnetid=`aws ec2 create-subnet --vpc-id $vpcid --cidr-block 10.0.0.0/28 --output=text|awk {'print $6'}`

#Step 3: Create a custom security group per this VPC - store the group ID in a variable (awk $jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj1)
secgroupid=`aws ec2 create-security-group --group-name ito444  --description "Security group for this classes test script" --vpc-id $vpcid --output=text|awk {'print $1'}`

#step 3b:  Open the ports For SSH and WEB access to your security group ( this one I give you)
aws ec2 authorize-security-group-ingress --group-id $secgroupid --protocol tcp --port 80 --cidr 0.0.0.0/0 --output=text
aws ec2 authorize-security-group-ingress --group-id $secgroupid --protocol tcp --port 22 --cidr 0.0.0.0/0 --output=text 

#Step 4: We need to create an internet gateway so that our VPC has internet access - save the gaetway ID to a vaiable (awk column 2)
gatewayid=`aws ec2 create-internet-gateway --output=text|awk {'print $2'}`

#step 4b:  We need to modify the VPC attributes to enable dns support and enable dns hostnames - see the examples note that you cannot combine these options you have to make two modify entries
aws ec2 modify-vpc-attribute --vpc-id $vpcid --enable-dns-support --output=text
aws ec2 modify-vpc-attribute --vpc-id $vpcid --enable-dns-hostnames --output=text

#Step 5 Modify-subnet-attribute - tell the subnet id to --map-public-ip-on-launch
aws ec2 modify-subnet-attribute  --subnet-id $subnetid --map-public-ip-on-launch --output=text

#Step 6:  We need to attach the internet gateway we created to our VPC
aws ec2 attach-internet-gateway --internet-gateway-id $gatewayid --vpc-id $vpcid --output=text

#Step 6b: Now lets create a ROUTETABLE variable and use the command create-route-table command to get the routetable id us  | grep rtb | awk {'print $2'}
routetableid=`aws ec2 create-route-table --vpc-id $vpcid| grep rtb | awk {'print $2'}`

#Step 6c: Now we create a route to be attached to the route table (I know its kind of verbose but this is what the GUI is doing automatically)  --destination-cidr-block is 0.0.0.0/0
aws ec2 create-route --route-table-id $routetableid --destination-cidr-block 0.0.0.0/0 --gateway-id=$gatewayid --output=text
# Now associate that route with a route-table-id and a subnet-id
aws ec2 associate-route-table --subnet-id $subnetid --route-table-id $routetableid --output=text

#Step 7:  Now create a ELBURL variable and lets create a load balancer - change from the EC2 cli docs to the ELB docs.  Use the default example --listeners from the VPC section (not classic EC2 routing)) I am leaving some formatting code in here that will print '.' for a time to give the system time to finish registering
ELBURL=`aws elb create-load-balancer --load-balancer-name $1 --listeners Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80 --subnets $subnetid --security-groups $secgroupid --output=text`

echo -e "\nFinished launching ELB and sleeping 25 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#step 7b: This is the elb configure-health-check this section is what the loadbalancer will be checking and how often - use the code that is in the example and check in HTTP:80/index.html
aws elb configure-health-check --load-balancer-name $1 --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3 --output=text

echo -e "\nFinished ELB health check and sleeping 30 seconds"
for i in {0..25}; do echo -ne '.'; sleep 1;done

#Step 8: Here is where we launch our instances, provide the VPC configuration, provide client-tokens, and provide the user-data via the file:// handler setup-MA3.sh -- See EC2 docs run-instances example for VPC launch (Good thing you saved those id's into variable so you could access them later in the script.)
aws ec2 run-instances --image-id ami-e84d8480  --count $3 --user-data=file://newma.sh --instance-type t1.micro  --security-group-ids $secgroupid --subnet-id $subnetid --client-token $2 --iam-instance-profile Name="iamaccess" --key-name $5 --output=text

echo -e "\nFinished launching EC2 Instances and sleeping 60 seconds"
for i in {0..60}; do echo -ne '.'; sleep 1;done
echo -e "\nFinished launching EC2 Instances and sleeping 60 seconds"
for i in {0..60}; do echo -ne '.'; sleep 1;done

#Step 9: Here we declare an array in BASH and list our instances - then we use the --filters Name=client-token,Values=(your value here)   --output=text | grep INSTANCES | awk {'print $*'}  that should get your the instance-ids
declare -a ARRAY 
ARRAY=(`aws ec2 describe-instances --filters Name=client-token,Values=$2 --output text | grep INSTANCES | awk {' print $8'}`)
echo -e "\nListing Instances, filtering their instance-id, adding them to an ARRAY and sleeping 15 seconds"
for i in {0..15}; do echo -ne '.'; sleep 1;done

#Step 10: Here the first line calculates the length of the array $# is a system variable that know its length.   Now we loop through the instance array and add each instance to our loadbalancer one by one and print out the progress. I give this one to you 
LENGTH=${#ARRAY[@]}
echo "ARRAY LENGTH IS $LENGTH"
for (( i=0; i<${LENGTH}; i++)); 
  do
  echo "Registering ${ARRAY[$i]} with load-balancer $1" 
  aws elb register-instances-with-load-balancer --load-balancer-name $1 --instances ${ARRAY[$i]} --output=table 
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


#Last Step
firefox $ELBURL &

fi  #End of if statement

