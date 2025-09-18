#!/bin/bash

# AWS EC2 Automation Script
# This script launches an EC2 instance, creates an EBS volume, and allocates an Elastic IP

set -e  # Exit on any error

# Load configuration from aws-config.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/aws-config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "✓ Loaded configuration from aws-config.env"
else
    echo "❌ Error: aws-config.env file not found at $CONFIG_FILE"
    echo "Please create the aws-config.env file with required AWS configuration."
    exit 1
fi

# Set REGION variable from AWS_DEFAULT_REGION for script compatibility
REGION="$AWS_DEFAULT_REGION"

# Validate required environment variables
validate_config() {
    local missing_vars=()

    [ -z "$AWS_ACCESS_KEY_ID" ] && missing_vars+=("AWS_ACCESS_KEY_ID")
    [ -z "$AWS_SECRET_ACCESS_KEY" ] && missing_vars+=("AWS_SECRET_ACCESS_KEY")
    [ -z "$AWS_DEFAULT_REGION" ] && missing_vars+=("AWS_DEFAULT_REGION")
    [ -z "$KEY_NAME" ] && missing_vars+=("KEY_NAME")
    [ -z "$SECURITY_GROUP" ] && missing_vars+=("SECURITY_GROUP")
    [ -z "$INSTANCE_TYPE" ] && missing_vars+=("INSTANCE_TYPE")
    [ -z "$AMI_ID" ] && missing_vars+=("AMI_ID")
    [ -z "$VOLUME_SIZE" ] && missing_vars+=("VOLUME_SIZE")
    [ -z "$AVAILABILITY_ZONE" ] && missing_vars+=("AVAILABILITY_ZONE")

    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "❌ Error: Missing required environment variables:"
        printf '  - %s\n' "${missing_vars[@]}"
        echo "Please check your aws-config.env file."
        exit 1
    fi
    echo "✓ All required configuration variables are set"
}

# Function to display usage
show_usage() {
    echo "AWS EC2 Automation Script"
    echo ""
    echo "This script automatically:"
    echo "  1. Launches an EC2 instance"
    echo "  2. Creates and attaches an EBS volume"
    echo "  3. Allocates and associates an Elastic IP"
    echo ""
    echo "Usage:"
    echo "  ./instance-auto-creation.sh"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI installed and configured"
    echo "  - aws-config.env file with required configuration"
    echo "  - Valid AWS credentials in aws-config.env"
    echo ""
    echo "For help: ./instance-auto-creation.sh --help"
}


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS CLI configuration..."
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS CLI is not configured or credentials are invalid"
        print_status "Please run: aws configure"
        exit 1
    fi
    print_status "AWS CLI is properly configured"
}

# Function to get default VPC and subnet if not specified
get_default_network() {
    if [ -z "$SUBNET_ID" ]; then
        print_status "Getting default VPC subnet..."
        SUBNET_ID=$(aws ec2 describe-subnets \
            --region $REGION \
            --filters "Name=default-for-az,Values=true" "Name=availability-zone,Values=$AVAILABILITY_ZONE" \
            --query 'Subnets[0].SubnetId' \
            --output text)
        
        if [ "$SUBNET_ID" = "None" ] || [ -z "$SUBNET_ID" ]; then
            print_error "Could not find default subnet in $AVAILABILITY_ZONE"
            exit 1
        fi
        print_status "Using subnet: $SUBNET_ID"
    fi
}

# Function to launch EC2 instance
launch_ec2_instance() {
    print_status "Launching EC2 instance..."
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SECURITY_GROUP \
        --subnet-id $SUBNET_ID \
        --region $REGION \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=AutomatedEC2Instance}]' \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    if [ -z "$INSTANCE_ID" ]; then
        print_error "Failed to launch EC2 instance"
        exit 1
    fi
    
    print_status "EC2 instance launched with ID: $INSTANCE_ID"
    
    # Wait for instance to be running
    print_status "Waiting for instance to be in running state..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
    print_status "Instance is now running"
}

# Function to create and attach EBS volume
create_and_attach_ebs() {
    print_status "Creating EBS volume..."
    
    VOLUME_ID=$(aws ec2 create-volume \
        --size $VOLUME_SIZE \
        --volume-type gp3 \
        --availability-zone $AVAILABILITY_ZONE \
        --region $REGION \
        --tag-specifications 'ResourceType=volume,Tags=[{Key=Name,Value=AutomatedEBSVolume}]' \
        --query 'VolumeId' \
        --output text)
    
    if [ -z "$VOLUME_ID" ]; then
        print_error "Failed to create EBS volume"
        exit 1
    fi
    
    print_status "EBS volume created with ID: $VOLUME_ID"
    
    # Wait for volume to be available
    print_status "Waiting for EBS volume to be available..."
    aws ec2 wait volume-available --volume-ids $VOLUME_ID --region $REGION
    print_status "EBS volume is now available"
    
    # Attach volume to instance
    print_status "Attaching EBS volume to instance..."
    aws ec2 attach-volume \
        --volume-id $VOLUME_ID \
        --instance-id $INSTANCE_ID \
        --device /dev/sdf \
        --region $REGION > /dev/null
    
    print_status "EBS volume attached to instance as /dev/sdf"
}

# Function to allocate and associate Elastic IP
allocate_and_associate_eip() {
    print_status "Allocating Elastic IP..."
    
    ALLOCATION_ID=$(aws ec2 allocate-address \
        --domain vpc \
        --region $REGION \
        --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=AutomatedEIP}]' \
        --query 'AllocationId' \
        --output text)
    
    if [ -z "$ALLOCATION_ID" ]; then
        print_error "Failed to allocate Elastic IP"
        exit 1
    fi
    
    # Get the public IP address
    PUBLIC_IP=$(aws ec2 describe-addresses \
        --allocation-ids $ALLOCATION_ID \
        --region $REGION \
        --query 'Addresses[0].PublicIp' \
        --output text)
    
    print_status "Elastic IP allocated: $PUBLIC_IP (Allocation ID: $ALLOCATION_ID)"
    
    # Associate Elastic IP with instance
    print_status "Associating Elastic IP with instance..."
    ASSOCIATION_ID=$(aws ec2 associate-address \
        --instance-id $INSTANCE_ID \
        --allocation-id $ALLOCATION_ID \
        --region $REGION \
        --query 'AssociationId' \
        --output text)
    
    print_status "Elastic IP associated with instance (Association ID: $ASSOCIATION_ID)"
}

# Function to display summary
display_summary() {
    print_status "=== DEPLOYMENT SUMMARY ==="
    echo "Region: $REGION"
    echo "Instance ID: $INSTANCE_ID"
    echo "Instance Type: $INSTANCE_TYPE"
    echo "EBS Volume ID: $VOLUME_ID"
    echo "EBS Volume Size: ${VOLUME_SIZE}GB"
    echo "Elastic IP: $PUBLIC_IP"
    echo "Allocation ID: $ALLOCATION_ID"
    echo ""
    print_status "SSH Command: ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP"
    print_status "To mount the EBS volume, SSH into the instance and run:"
    echo "  sudo mkfs -t xfs /dev/xvdf"
    echo "  sudo mkdir /mnt/mydata"
    echo "  sudo mount /dev/xvdf /mnt/mydata"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Script failed. Cleaning up resources..."
    
    if [ ! -z "$ASSOCIATION_ID" ]; then
        print_status "Disassociating Elastic IP..."
        aws ec2 disassociate-address --association-id $ASSOCIATION_ID --region $REGION || true
    fi
    
    if [ ! -z "$ALLOCATION_ID" ]; then
        print_status "Releasing Elastic IP..."
        aws ec2 release-address --allocation-id $ALLOCATION_ID --region $REGION || true
    fi
    
    if [ ! -z "$VOLUME_ID" ]; then
        print_status "Deleting EBS volume..."
        aws ec2 delete-volume --volume-id $VOLUME_ID --region $REGION || true
    fi
    
    if [ ! -z "$INSTANCE_ID" ]; then
        print_status "Terminating EC2 instance..."
        aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION || true
    fi
}

# Trap to cleanup on script failure
trap cleanup_on_error ERR

# Main execution
main() {
    print_status "Starting AWS EC2 automation script..."

    # Validate configuration and prerequisites
    validate_config
    check_aws_config
    get_default_network
    
    # Execute main tasks
    launch_ec2_instance
    create_and_attach_ebs
    allocate_and_associate_eip
    
    # Display results
    display_summary
    
    print_status "Script completed successfully!"
}

# Check if script is being run directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    # Handle help argument
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        show_usage
        exit 0
    fi

    main "$@"
fi
