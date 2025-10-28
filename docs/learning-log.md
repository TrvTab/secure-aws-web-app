# Project 1 — AWS 3-Tier VPC & RDS (Learning Summary)

🌐 1. Nginx, NAT, and Networking Basics

Nginx purpose: Acts as a reverse proxy to route requests to backend servers and handle HTTPS termination (port 443).

Default port access: EC2 instances only allow SSH (22) by default for admin safety.

Why curl failed inside SSH: Inside the EC2, requests were sent from a private IP with no outbound route — fixed via NAT.

0.0.0.0 meaning: Represents “any IPv4 address.” Used in route tables to mean “default route to anywhere.”

Why not a /20 CIDR: Smaller subnets (/24) are easier to expand (add new /24s later) without renumbering the entire network.

🧱 2. VPC Architecture & Subnet Design

Public subnets: Have routes to the Internet Gateway (IGW).

Private subnets: Have routes to a NAT Gateway (for outbound-only internet).

DB subnets: Should not route to IGW, only NAT or stay fully internal.

Every subnet has its own route table, which decides outbound paths — subnets do not route through each other.

IGW routing is one-way: The IGW handles return traffic automatically but only for instances with public IPs.

Private instances → Internet: Must go through a NAT Gateway (not IGW) because they lack public IPs.

Elastic IP: A static, public IP address you assign to a NAT Gateway or EC2. The IGW doesn’t have its own IP.

NAT per AZ: Start with one NAT Gateway (cheaper); later scale to one per AZ for fault tolerance.

Elastic IP vs IGW: IGW is just a bridge — Elastic IPs live on NAT or EC2 resources that connect through it.

🗄️ 3. RDS & Database Architecture

Multi-AZ RDS: Primary DB + synchronous standby in another AZ. One endpoint stays constant.

DB subnet group: Defines which private subnets RDS can use; must have ≥2 subnets in ≥2 AZs.

Subnet group in single AZ setups: Still needs two subnets (so it’s ready for Multi-AZ later).

Public access: Should be disabled for private RDS setups.

Modifying from Single-AZ → Multi-AZ: Supported via modify-db-instance --multi-az.

Creating DB subnet group: You pick private subnets (e.g., 10.0.21.0/24 & 10.0.22.0/24) across two AZs.

“Wrong VPC” error: Usually caused by missing current AZ in subnet group, or the EC2 “connected” helper blocking changes — not actually a VPC mismatch.

EC2 connection (wizard): AWS auto-created rds-ec2-X and ec2-rds-X SGs to simplify connectivity.

🔒 4. Security Groups & Access Control

rds-ec2-1 (DB SG): Attached to RDS; inbound 5432 from ec2-rds-1.

ec2-rds-1 (App SG): Attached to EC2; outbound 5432 to RDS SG.

web-tier-sg: Handles inbound 80/443 for app traffic (from ALB or your IP), outbound 0.0.0.0/0.

No SSH on web-tier SG: Use SSM or a Bastion Host for access instead.

Security group rules are stateful: Return traffic automatically allowed.

VPC endpoints: Let private subnets reach AWS services (S3, SSM, Secrets Manager) without going through NAT.

🧠 5. AWS Systems Manager (SSM)

Preferred method for private EC2 access (no SSH exposure).

Setup: EC2 must have IAM role with AmazonSSMManagedInstanceCore.

CloudShell check: You can verify attachment with:

aws ec2 describe-iam-instance-profile-associations


Attach if missing: Use associate-iam-instance-profile.

Stopped instance: Doesn’t affect IAM attachment, but it must be running for SSM to show “Online.”

🧩 6. Route Tables, Testing, and NAT Verification

Route flow:

Public RT → IGW.

Private Web RT → NAT.

Private DB RT → Local or NAT (no IGW).

Testing from EC2:

curl -s ifconfig.me → shows NAT’s Elastic IP.

sudo apt update → confirms outbound internet.

nc -vz <RDS-ENDPOINT> 5432 → confirms DB connectivity.