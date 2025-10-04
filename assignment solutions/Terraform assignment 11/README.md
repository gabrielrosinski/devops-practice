# Terraform Assignment 11 - EC2 Instance Deployment

This Terraform configuration deploys a t2.micro EC2 instance running Ubuntu 24.04 LTS with a security group for SSH access.

## Prerequisites

### 1. AWS CLI Configuration

Configure AWS credentials on your local machine:

```bash
aws configure
```

You'll need:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Default output format (e.g., `json`)

Download your AWS credentials CSV file from IAM console when creating access keys.

### 2. EC2 Key Pair

Create an EC2 key pair in AWS Console for SSH access:

1. Go to AWS Console → EC2 → Key Pairs
2. Click "Create key pair"
3. Name it (e.g., `task1-user`)
4. Choose `.pem` format
5. Download and save to `~/.ssh/` directory
6. Set proper permissions:
   ```bash
   chmod 400 ~/.ssh/task1-user.pem
   ```

### 3. Create terraform.tfvars File

The `terraform.tfvars` file is excluded from version control for security reasons. Create it manually:

```bash
# Create terraform.tfvars in the project directory
cat > terraform.tfvars <<EOF
aws_region       = "us-east-1"
key_name         = "task1-user"
ssh_ingress_cidr = "YOUR_PUBLIC_IP/32"
EOF
```

**Important:** Replace `YOUR_PUBLIC_IP` with your actual public IP address. You can find it by visiting https://whatismyip.com or running:
```bash
curl ifconfig.me
```

Example:
```hcl
aws_region       = "us-east-1"
key_name         = "task1-user"
ssh_ingress_cidr = "46.117.112.88/32"
```

## Deployment

### Initialize Terraform

```bash
terraform init
```

### Validate Configuration

```bash
terraform validate
```

### Preview Changes

```bash
terraform plan
```

### Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### Get Outputs

After deployment, Terraform will display:
- Instance ID
- Public IP address
- SSH command to connect

## Connect to Instance

```bash
ssh -i ~/.ssh/task1-user.pem ubuntu@<public-ip>
```

Replace `<public-ip>` with the IP from Terraform output.

## Post-Deployment Setup

### Docker Installation

Docker and Docker Compose were installed on the instance:

```bash
# Update packages
sudo apt update

# Install Docker
sudo apt install -y docker.io

# Start Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo apt install -y docker-compose

# Log out and back in for group changes to take effect
exit
```

### WordPress Deployment (Testing)

A WordPress server with MySQL was deployed for testing purposes:

**docker-compose.yml:**
```yaml
version: '3'

services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: somewordpress
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
    volumes:
      - db_data:/var/lib/mysql
    restart: always

  wordpress:
    depends_on:
      - db
    image: wordpress:latest
    ports:
      - "8000:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress_data:/var/www/html
    restart: always

volumes:
  db_data:
  wordpress_data:
```

**Deploy WordPress:**
```bash
docker-compose up -d
```

**Access WordPress:**
- Open browser: `http://<public-ip>:8000`

**Note:** Port 8000 must be open in the security group to access WordPress from your browser.

## Infrastructure Details

### Resources Created

- **EC2 Instance:** t2.micro (Free Tier eligible)
- **AMI:** Ubuntu 24.04 LTS (Noble) with GP3 storage
- **Security Group:** SSH access from specified IP, HTTP on port 8000, all egress allowed
- **VPC:** Default VPC
- **Subnet:** First available subnet in default VPC
- **Termination Protection:** Enabled

### Security Features

- SSH restricted to single IP address (specified in `ssh_ingress_cidr`)
- HTTP traffic on port 8000 (for WordPress testing)
- API termination protection enabled
- All resources tagged with Environment and ManagedBy

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

**Note:** This will permanently delete the EC2 instance and all associated resources.

## Files

- `main.tf` - Main infrastructure configuration
- `providers.tf` - Terraform and AWS provider configuration
- `variables.tf` - Variable declarations
- `output.tf` - Output values (instance ID, public IP, SSH command)
- `terraform.tfvars` - Variable values (NOT in version control)

## Free Tier Usage

This deployment uses AWS Free Tier resources:
- 750 hours/month of t2.micro instances (12 months)
- 30 GB of GP3 EBS storage
- 100 GB data transfer out per month

## Troubleshooting

### Key pair not found error
Ensure the key pair name in `terraform.tfvars` matches the name created in AWS Console.

### Permission denied when using Docker
Log out and back into the EC2 instance after adding user to docker group.

### Cannot access WordPress
Ensure port 8000 is open in the security group ingress rules.
