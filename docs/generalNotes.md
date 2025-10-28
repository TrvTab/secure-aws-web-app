# Daily Tasks

## October 22, 2025

### The following was done to ensure that my architecture was built the way i wanted it to be

# Project 1 – Pre-October 20 Validation Guide

**Secure AWS Web App — 3-Tier VPC Architecture**

This checklist verifies that your AWS environment is correctly configured before starting **Week 3 (October 20)** — when the **Application Load Balancer (ALB)** is deployed.

---

## 📍 Step 0: Region & Account Verification

Confirm you're operating in the correct AWS region and account:

```bash
echo $AWS_DEFAULT_REGION
aws sts get-caller-identity --query "Account" --output text
```

**Expected Result:** Verify you're in the correct region (e.g., `us-east-2`) and AWS account.

---

## 🌐 Step 1: List All Subnets in Your VPC

```bash
VPC_ID=<YOUR_VPC_ID>
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].{Id:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,RT:RouteTable.Associations[0].RouteTableId}" \
  --output table
```

**Expected CIDR Patterns:**

- Public subnets: `10.0.1.0/24`, `10.0.2.0/24`
- Web (private) subnets: `10.0.11.0/24`, `10.0.12.0/24`
- DB (private) subnets: `10.0.21.0/24`, `10.0.22.0/24`

---

## 🗺️ Step 2: Route Tables Validation

```bash
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "RouteTables[].{Id:RouteTableId,Routes:Routes[?DestinationCidrBlock=='0.0.0.0/0']}" \
  --output json
```

**Expected Configuration:**

- **Public RT** → Routes to `igw-...` (Internet Gateway)
- **Private-Web RT** → Routes to `nat-...` (NAT Gateway)
- **Private-DB RT** → No IGW route (none or NAT only)

---

## 🌉 Step 3: NAT Gateway Verification

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" \
  --query "NatGateways[].{Id:NatGatewayId,Subnet:SubnetId,EIP:NatGatewayAddresses[0].PublicIp,State:State}" \
  --output table
```

**Expected Result:** NAT Gateway should be:

- Located in a public subnet
- Have an Elastic IP assigned
- Show `State = available`

---

## 🗄️ Step 4: RDS Instance Details

```bash
DB_ID=<YOUR_DB_IDENTIFIER>
aws rds describe-db-instances --db-instance-identifier $DB_ID \
  --query "DBInstances[0].{Endpoint:Endpoint.Address,Engine:Engine,MultiAZ:MultiAZ,Public:PubliclyAccessible,SubnetGroup:DBSubnetGroup.DBSubnetGroupName,VPC:DBSubnetGroup.VpcId,SGs:VpcSecurityGroups[*].VpcSecurityGroupId}" \
  --output table
```

**Expected Result:**

- `PubliclyAccessible = False`
- VPC ID matches your main VPC

---

## 🗃️ Step 5: DB Subnet Group Spread

```bash
DBSG=$(aws rds describe-db-instances --db-instance-identifier $DB_ID \
  --query "DBInstances[0].DBSubnetGroup.DBSubnetGroupName" --output text)

aws rds describe-db-subnet-groups --db-subnet-group-name "$DBSG" \
  --query "DBSubnetGroups[0].Subnets[].{Subnet:SubnetIdentifier,AZ:SubnetAvailabilityZone.Name}" \
  --output table
```

**Expected Result:**

- Must show **two availability zones** (e.g., `us-east-2a` and `us-east-2b`)
- Using your DB subnets
- Those subnets' route tables must **not** route to an IGW

---

## 🔒 Step 6: Security Groups Configuration

### List All Security Groups

```bash
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[].{Id:GroupId,Name:GroupName}" --output table
```

### Inspect RDS Security Group Inbound Rules

```bash
RDS_SG=<RDS_SECURITY_GROUP_ID>
aws ec2 describe-security-groups --group-ids $RDS_SG \
  --query "SecurityGroups[0].IpPermissions" --output json
```

**Expected Result:**

- Inbound: TCP port 5432 from EC2 Security Group (not `0.0.0.0/0`)

### Inspect Web-Tier Security Group

```bash
WEB_SG=<WEB_SECURITY_GROUP_ID>
aws ec2 describe-security-groups --group-ids $WEB_SG \
  --query "{Inbound:SecurityGroups[0].IpPermissions,Outbound:SecurityGroups[0].IpPermissionsEgress}" --output json
```

**Expected Result:**

- **Inbound:** Ports 80/443 from ALB Security Group (or your IP)
- **Outbound:** `0.0.0.0/0` (allow all)

---

## 🧩 Step 7: EC2 Instances & SSM Role

```bash
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Reservations[].Instances[].{Id:InstanceId,Name:Tags[?Key=='Name']|[0].Value,State:State.Name,Subnet:SubnetId,PrivateIp:PrivateIpAddress,SGs:SecurityGroups[*].GroupId,SSM:IamInstanceProfile.Arn}" \
  --output table
```

**Expected Result:**

- EC2 instance is in a private web subnet
- Has **no public IP**
- Has an IAM profile with `AmazonSSMManagedInstanceCore`

### SSM role was missing

```bash
INSTANCE_ID=<YOUR_INSTANCE_ID>
ROLE_NAME=EC2-SSM-Role

# Create IAM role
aws iam create-role --role-name $ROLE_NAME \
  --assume-role-policy-document file://<(echo '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}')

# Attach SSM policy
aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create and attach instance profile
aws iam create-instance-profile --instance-profile-name EC2-SSM-Profile
aws iam add-role-to-instance-profile --instance-profile-name EC2-SSM-Profile --role-name $ROLE_NAME
aws ec2 associate-iam-instance-profile --instance-id $INSTANCE_ID \
  --iam-instance-profile Name=EC2-SSM-Profile
```

---

## 🧠 Step 8: Connectivity Test (from Private EC2)

### Start SSM Session

```bash
EC2_ID=<YOUR_INSTANCE_ID>
aws ssm start-session --target $EC2_ID
```

### Inside the SSM Session

```bash
# Test NAT Gateway connectivity
curl -s ifconfig.me                 # Should show NAT EIP

# Test outbound internet access
sudo apt-get update -y

# Test database connectivity
DB_ENDPOINT=<YOUR_RDS_ENDPOINT>
timeout 3 bash -c "</dev/tcp/$DB_ENDPOINT/5432" && echo "DB PORT OPEN" || echo "DB PORT CLOSED"
```

**Expected Result:**

- Internet works (via NAT Gateway)
- Database port 5432 is accessible

---

## 🧰 Step 9: (Optional) ALB Target Health

```bash
# List target groups
aws elbv2 describe-target-groups \
  --query "TargetGroups[].{Arn:TargetGroupArn,Port:Port,Protocol:Protocol}" --output table

# Check target health
TG_ARN=<YOUR_TG_ARN>
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --query "TargetHealthDescriptions[].TargetHealth" --output table
```

**Expected Result:** All targets show `healthy` status

---

## ✅ Pass Criteria Summary

| Component | Pass Condition |
|-----------|----------------|
| **NAT Gateway** | In public subnet + EIP + available status |
| **EC2 (Web)** | Private subnet + no public IP + SSM reachable |
| **RDS** | Private DB subnet group (2 AZs) + PubliclyAccessible = False |
| **Route Tables** | IGW on public only / NAT on private / None on DB |
| **Security Groups** | Web SG (80/443) + RDS SG (5432 from EC2 SG) |
| **Connectivity** | `apt update` works and `DB PORT OPEN` |


- Created POSTGRESQL database inside RDS instance
  name: first_project_db

- Created Application Load Balancer with alb-tier-sg security group. ALB is mapped to my 2 public subnets in side my vpc. It takes http/https traffic, ALB decrypts it, then sends it to EC2 on port 5000 using HTTP protocol. Don't have to send https since were already in trusted zone, ALB already decrypted information and are not implementing zero trust protocol. The http protocol and sending of ALB data to EC2 was done with the target group firstProject-alb-ec2-targetgroup. This will forward with http protocol to within my vpc

- Health check path on the root of target path (research). path chosen: /healthCheck

- removed the ec2-rds-sg and rds-ec2-sg, created rds-tier-sg. consolidated security group rules for simplicity