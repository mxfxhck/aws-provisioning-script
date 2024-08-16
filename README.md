# AWS Infrastructure Provisioning Script

Automated script for provisioning AWS infrastructure. Creates VPCs, subnets, security groups, EC2 instances (selectable OS), RDS instances, S3 buckets, and IAM roles with interactive user input.

## Features

- **VPC Creation**: Setup new VPCs.
- **Subnet Setup**: Create subnets in chosen availability zones.
- **Security Groups**: Configure inbound and outbound rules.
- **EC2 Instances**: Launch instances with selectable OS (Amazon Linux, Ubuntu, Windows, etc.).
- **RDS Instances**: Create and configure RDS instances.
- **S3 Buckets**: Create S3 buckets for storage.
- **IAM Roles**: Create and attach IAM roles and policies.

## Usage

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/yourusername/aws-infrastructure-provisioning.git
2. Navigate to the Script Directory:
   ```bash
   cd aws-infrastructure-provisioning
4. Make the Script Executable and Run:
   ```bash
   chmod +x provision.sh
   ./provision.sh
6. Follow the Prompts: Select OS, region, and availability zones.

Requirements - 
* AWS CLI installed and configured with necessary permissions.

License
* This project is licensed under the MIT License.






