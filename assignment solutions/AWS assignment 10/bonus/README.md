# AWS EC2 Automation Script

## Overview

This project provides automated AWS EC2 infrastructure provisioning through a bash script that orchestrates the complete creation and configuration of:
- EC2 instances with custom specifications
- EBS volumes with automatic attachment
- Elastic IP allocation and association
- Comprehensive error handling and resource cleanup

## Features

- **Automated Resource Provisioning**: One-command deployment of complete EC2 infrastructure
- **Configuration Management**: Environment-based configuration through `aws-config.env`
- **Error Handling**: Comprehensive cleanup mechanism prevents orphaned resources
- **Status Reporting**: Color-coded output with detailed deployment progress
- **Security**: Built-in safeguards to prevent credential exposure
- **Validation**: Pre-flight checks for AWS CLI configuration and required variables

## Project Structure

```
.
├── aws-config.env              # Environment configuration (credentials & parameters)
├── instance-auto-creation.sh   # Main automation script
└── README.md                   # This file
```

## Prerequisites

- AWS CLI installed and accessible in PATH
- Valid AWS account with appropriate permissions for:
  - EC2 instances (create, describe, terminate)
  - EBS volumes (create, attach, delete)
  - Elastic IPs (allocate, associate, release)
  - VPC/Subnet access
- Bash shell environment

## Installation

1. Clone or download this project
2. Copy the provided `aws-config.env` file and update with your AWS credentials
3. Make the script executable:
   ```bash
   chmod +x instance-auto-creation.sh
   ```

## Configuration

### Environment Variables

Create and configure `aws-config.env` with the following variables:

```bash
# AWS Credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# EC2 Configuration
export KEY_NAME="your-key-pair-name"
export SECURITY_GROUP="sg-xxxxxxxxx"
export INSTANCE_TYPE="t3.micro"
export AMI_ID="ami-xxxxxxxxx"
export VOLUME_SIZE="20"
export AVAILABILITY_ZONE="us-east-1a"
```

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_DEFAULT_REGION` | AWS Region | `us-east-1` |
| `KEY_NAME` | EC2 Key Pair name | `my-key-pair` |
| `SECURITY_GROUP` | Security Group ID | `sg-073729dfee781ac31` |
| `INSTANCE_TYPE` | EC2 Instance Type | `t3.micro` |
| `AMI_ID` | Amazon Machine Image ID | `ami-0c02fb55956c7d316` |
| `VOLUME_SIZE` | EBS Volume size in GB | `20` |
| `AVAILABILITY_ZONE` | AWS Availability Zone | `us-east-1a` |

## Usage

### Basic Usage

```bash
# Source configuration and run the script
source aws-config.env && ./instance-auto-creation.sh
```

### Help

```bash
./instance-auto-creation.sh --help
```

### Manual AWS Configuration Check

```bash
aws sts get-caller-identity
```

## Script Workflow

The automation script follows this sequence:

1. **Configuration Loading**: Sources environment variables from `aws-config.env`
2. **Validation**: Checks all required variables and AWS CLI configuration
3. **Network Discovery**: Retrieves default VPC subnet information
4. **EC2 Launch**: Creates and starts EC2 instance with specified configuration
5. **EBS Creation**: Creates EBS volume and attaches to instance as `/dev/sdf`
6. **Elastic IP**: Allocates and associates Elastic IP with the instance
7. **Summary**: Displays complete deployment information and SSH instructions

## Output Example

```
✓ Loaded configuration from aws-config.env
✓ All required configuration variables are set
[INFO] Checking AWS CLI configuration...
[INFO] AWS CLI is properly configured
[INFO] Getting default VPC subnet...
[INFO] Using subnet: subnet-xxxxxxxxx
[INFO] Launching EC2 instance...
[INFO] EC2 instance launched with ID: i-xxxxxxxxx
[INFO] Waiting for instance to be in running state...
[INFO] Instance is now running
[INFO] Creating EBS volume...
[INFO] EBS volume created with ID: vol-xxxxxxxxx
[INFO] Waiting for EBS volume to be available...
[INFO] EBS volume is now available
[INFO] Attaching EBS volume to instance...
[INFO] EBS volume attached to instance as /dev/sdf
[INFO] Allocating Elastic IP...
[INFO] Elastic IP allocated: 54.123.456.789 (Allocation ID: eipalloc-xxxxxxxxx)
[INFO] Associating Elastic IP with instance...
[INFO] Elastic IP associated with instance (Association ID: eipassoc-xxxxxxxxx)
[INFO] === DEPLOYMENT SUMMARY ===
Region: us-east-1
Instance ID: i-xxxxxxxxx
Instance Type: t3.micro
EBS Volume ID: vol-xxxxxxxxx
EBS Volume Size: 20GB
Elastic IP: 54.123.456.789
Allocation ID: eipalloc-xxxxxxxxx

[INFO] SSH Command: ssh -i ~/.ssh/your-key.pem ec2-user@54.123.456.789
[INFO] To mount the EBS volume, SSH into the instance and run:
  sudo mkfs -t xfs /dev/xvdf
  sudo mkdir /mnt/mydata
  sudo mount /dev/xvdf /mnt/mydata
[INFO] Script completed successfully!
```

## Error Handling

The script includes comprehensive error handling:

- **Immediate Exit**: Uses `set -e` to exit on any command failure
- **Resource Cleanup**: Automatically cleans up created resources on script failure
- **Validation**: Pre-flight checks prevent execution with invalid configuration
- **Trap Mechanism**: Bash traps ensure cleanup runs even on unexpected failures

### Manual Cleanup

If manual cleanup is needed, you can use these AWS CLI commands with the resource IDs from the deployment summary:

```bash
# Disassociate and release Elastic IP
aws ec2 disassociate-address --association-id eipassoc-xxxxxxxxx
aws ec2 release-address --allocation-id eipalloc-xxxxxxxxx

# Delete EBS volume (detach first if needed)
aws ec2 detach-volume --volume-id vol-xxxxxxxxx
aws ec2 delete-volume --volume-id vol-xxxxxxxxx

# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids i-xxxxxxxxx
```

## Security Considerations

⚠️ **Important Security Notes:**

- The `aws-config.env` file contains sensitive AWS credentials
- This file should **NEVER** be committed to version control
- The `.gitignore` file should include `aws-config.env`
- Use IAM roles when possible instead of hardcoded credentials
- Regularly rotate your AWS access keys
- Follow the principle of least privilege for AWS permissions

## Troubleshooting

### Common Issues

1. **AWS CLI not configured**
   - Run `aws configure` or check your credentials
   - Verify with `aws sts get-caller-identity`

2. **Permission denied errors**
   - Ensure your AWS credentials have necessary EC2, EBS, and VPC permissions
   - Check IAM policies for your user/role

3. **Subnet not found**
   - Verify the availability zone exists in your region
   - Check if default VPC exists in the region

4. **Key pair not found**
   - Ensure the key pair name in `KEY_NAME` exists in the specified region
   - Create a new key pair if needed: `aws ec2 create-key-pair --key-name my-key`

5. **Security group invalid**
   - Verify the security group ID exists in your VPC
   - Check the security group allows necessary inbound/outbound rules

## Contributing

This is an educational project for AWS Assignment 10. For improvements:

1. Test changes thoroughly in a safe AWS environment
2. Ensure security best practices are maintained
3. Update documentation for any new features

## License

This project is for educational purposes as part of AWS Assignment 10.