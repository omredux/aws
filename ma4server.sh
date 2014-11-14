#!/bin/bash
# The shell script has a usage pattern provide the data before hand and then reference it.
#example ./sampleinstall.sh jrh544-elb itmo544virtualbox webserverMA3 4 itmo-ma3-group
# In this shell script then value $1  would be the first argument about...jrh544-elb
# $2 would reference the second value itmo544virtualbox and so forth...
if [ $# != 4 ]
  then
  echo "This script needs 5 arguments/variables to run; KEYPAIR, CLIENT-TOKENS, NUMBER OF INSTANCES, and SECURITY-GROUP-NAME"
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

aws ec2 run-instances --image-id ami-e84d8480  --count $3 --instance-type t1.micro --key-name $1 --security-group-ids $secgroupid --subnet-id $subnetid --client-token $2  --user-data=file://newma.sh --output=text

echo -e "\nFinished launching EC2 Instances and sleeping 60 seconds"
for i in {0..60}; do echo -ne '.'; sleep 1;done



fi  #End of if statement

