#!/bin/bash

# Log file setup
LOGFILE="provisioning.log"
exec > >(tee -i $LOGFILE)
exec 2>&1

# Define AMI IDs for different operating systems
declare -A AMI_IDS
AMI_IDS["amazon-linux-2"]="ami-0ae8f15ae66fe8cda"
AMI_IDS["ubuntu-20.04"]="ami-04a81a99f5ec58529"
AMI_IDS["windows-server-2019"]="ami-07d9456e59793a7d5"
AMI_IDS["MacOS-Sonoma-server"]="ami-0cdb66d9dacb7e395"
AMI_IDS["Red Hat Enterprise Linux"]="ami-0583d8c7a9c35822c"
AMI_IDS["SUSE Linux Enterprise Server"]="ami-0b247d4d0226ca7cd"
AMI_IDS["Debian 12 (HVM)"]="ami-00402f0bdf4996822"

# Function to prompt user for AWS region choice
prompt_region_choice() {
    echo "Select the AWS region:"
    echo "1) us-east-1"
    echo "2) us-west-1"
    echo "3) us-west-2"
    echo "4) eu-west-1"
    read -p "Enter the number of your choice: " region_choice

    case $region_choice in
        1)
            AWS_REGION="us-east-1"
            ;;
        2)
            AWS_REGION="us-west-1"
            ;;
        3)
            AWS_REGION="us-west-2"
            ;;
        4)
            AWS_REGION="eu-west-1"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

# Function to prompt user for availability zone choices
prompt_az_choices() {
    echo "Select the first availability zone:"
    echo "1) ${AWS_REGION}a"
    echo "2) ${AWS_REGION}b"
    echo "3) ${AWS_REGION}c"
    read -p "Enter the number of your choice: " az_choice1

    echo "Select the second availability zone:"
    echo "1) ${AWS_REGION}a"
    echo "2) ${AWS_REGION}b"
    echo "3) ${AWS_REGION}c"
    read -p "Enter the number of your choice: " az_choice2

    case $az_choice1 in
        1)
            AVAILABILITY_ZONE1="${AWS_REGION}a"
            ;;
        2)
            AVAILABILITY_ZONE1="${AWS_REGION}b"
            ;;
        3)
            AVAILABILITY_ZONE1="${AWS_REGION}c"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    case $az_choice2 in
        1)
            AVAILABILITY_ZONE2="${AWS_REGION}a"
            ;;
        2)
            AVAILABILITY_ZONE2="${AWS_REGION}b"
            ;;
        3)
            AVAILABILITY_ZONE2="${AWS_REGION}c"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    if [ "$AVAILABILITY_ZONE1" == "$AVAILABILITY_ZONE2" ]; then
        echo "Both availability zones cannot be the same. Exiting."
        exit 1
    fi
}

# Function to prompt user for OS choice
prompt_os_choice() {
    echo "Select the operating system for the EC2 instance:"
    echo "1) Amazon Linux 2"
    echo "2) Ubuntu 20.04 LTS"
    echo "3) Windows Server 2019"
    echo "4) MacOS-Sonoma-server"
    echo "5) Red Hat Enterprise Linux"
    echo "6) SUSE Linux Enterprise Server"
    echo "7) Debian 12 (HVM)"
    read -p "Enter the number of your choice: " os_choice

    case $os_choice in
        1)
            OS_NAME="amazon-linux-2"
            ;;
        2)
            OS_NAME="ubuntu-20.04"
            ;;
        3)
            OS_NAME="windows-server-2019"
            ;;
        4)  
            OS_NAME="MacOS-Sonoma-server"
            ;;
        5)  
            OS_NAME="Red Hat Enterprise Linux"
            ;;
        6)  
            OS_NAME="SUSE Linux Enterprise Server"
            ;;
        7)  
            OS_NAME="Debian 12 (HVM)"
            ;;    
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    AMI_ID=${AMI_IDS[$OS_NAME]}
}

# Function to create a VPC
create_vpc() {
    VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $AWS_REGION --query 'Vpc.VpcId' --output text)
    if [ $? -ne 0 ]; then
        echo "Error creating VPC"
        exit 1
    fi
    echo "VPC created: $VPC_ID"
}

# Function to create subnets
create_subnets() {
    SUBNET_ID1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone $AVAILABILITY_ZONE1 --region $AWS_REGION --query 'Subnet.SubnetId' --output text)
    if [ $? -ne 0 ]; then
        echo "Error creating Subnet in $AVAILABILITY_ZONE1"
        exit 1
    fi
    echo "Subnet created in $AVAILABILITY_ZONE1: $SUBNET_ID1"

    SUBNET_ID2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone $AVAILABILITY_ZONE2 --region $AWS_REGION --query 'Subnet.SubnetId' --output text)
    if [ $? -ne 0 ]; then
        echo "Error creating Subnet in $AVAILABILITY_ZONE2"
        exit 1
    fi
    echo "Subnet created in $AVAILABILITY_ZONE2: $SUBNET_ID2"
}

# Function to create a security group
create_security_group() {
    SG_ID=$(aws ec2 create-security-group --group-name unique-sg --description "Allow inbound traffic on port 22" --vpc-id $VPC_ID --region $AWS_REGION --query 'GroupId' --output text)
    if [ $? -ne 0 ]; then
        echo "Error creating Security Group"
        exit 1
    fi
    echo "Security group created: $SG_ID"

    # Authorize inbound SSH traffic on port 22
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $AWS_REGION
}

# Function to create a DB Subnet Group
create_db_subnet_group() {
    DB_SUBNET_GROUP_NAME="unique-db-subnet-group-$(date +%s)" # Unique name with timestamp
    aws rds create-db-subnet-group \
        --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
        --db-subnet-group-description "DB Subnet Group" \
        --subnet-ids $SUBNET_ID1 $SUBNET_ID2 \
        --region $AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Error creating DB Subnet Group"
        exit 1
    fi
    echo "DB Subnet Group created: $DB_SUBNET_GROUP_NAME"
}

# Function to create an EC2 instance
create_ec2_instance() {
    if [ -z "$AMI_ID" ]; then
        echo "AMI ID is not set. Exiting."
        exit 1
    fi

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type t2.micro \
        --security-group-ids $SG_ID \
        --subnet-id $SUBNET_ID1 \
        --key-name aws-key \
        --region $AWS_REGION \
        --query 'Instances[0].InstanceId' \
        --output text)
    if [ $? -ne 0 ]; then
        echo "Error creating EC2 Instance"
        exit 1
    fi
    echo "EC2 instance created: $INSTANCE_ID"
}

# Function to create an RDS instance
create_rds_instance() {
    RDS_INSTANCE_ID="unique-db-identifier-$(date +%s)"  # Use timestamp for uniqueness
    aws rds create-db-instance \
        --db-instance-identifier $RDS_INSTANCE_ID \
        --db-instance-class db.t3.micro \
        --engine mysql \
        --engine-version 8.0.35 \
        --allocated-storage 20 \
        --master-username adminuser \
        --master-user-password adminpassword \
        --vpc-security-group-ids $SG_ID \
        --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
        --query 'DBInstance.DBInstanceIdentifier' \
        --output text
    if [ $? -ne 0 ]; then
        echo "Error creating RDS Instance"
        exit 1
    fi
    echo "RDS instance created: $RDS_INSTANCE_ID"
}

# Function to create an S3 bucket
create_s3_bucket() {
    # Generate a unique bucket name using a timestamp
    BUCKET_NAME="unique-bucket-$(date +%s)"
    aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Error creating S3 Bucket"
        exit 1
    fi
    echo "S3 bucket created: $BUCKET_NAME"
}

# Function to create IAM role and policies
create_iam_role_and_policy() {
    ROLE_NAME="unique-role"
    aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://role-policy.json --region $AWS_REGION
    if [ $? -ne 0 ]; then
        echo "Error creating IAM Role"
        exit 1
    fi
    echo "IAM role created: $ROLE_NAME"
    
    POLICY_NAME="unique-policy"
    aws iam create-policy --policy-name $POLICY_NAME --policy-document file://policy.json --region $AWS_REGION
    echo "IAM policy created: $POLICY_NAME"
    
    aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::123456789012:policy/$POLICY_NAME --region $AWS_REGION
    
    INSTANCE_PROFILE_NAME="unique-instance-profile"
    aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --region $AWS_REGION
    echo "IAM instance profile created: $INSTANCE_PROFILE_NAME"
    
    aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME --role-name $ROLE_NAME --region $AWS_REGION
    
    aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID --iam-instance-profile Name=$INSTANCE_PROFILE_NAME --region $AWS_REGION
}

# Main execution
prompt_region_choice
prompt_az_choices
prompt_os_choice
create_vpc
create_subnets
create_security_group
create_db_subnet_group
create_ec2_instance
create_rds_instance
create_s3_bucket
create_iam_role_and_policy

echo "Infrastructure provisioning complete."
