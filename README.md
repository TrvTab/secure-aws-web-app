# Secure AWS Web Application

A security-focused Flask REST API demonstrating defense-in-depth principles with 5 distinct security layers and comprehensive JWT-based authentication. Built to showcase OWASP Top 10 mitigation strategies and secure cloud architecture.

**Key Achievement:** Complete coverage of OWASP Top 10 vulnerabilities with 28 automated security tests validating all controls (100% pass rate).

---

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Security Controls](#security-controls)
- [OWASP Top 10 Coverage](#owasp-top-10-coverage)
- [Security Testing](#security-testing)
- [Technologies Used](#technologies-used)
- [Deployment](#deployment)

---

## Overview

This project implements a production-ready Flask REST API with JWT authentication deployed on AWS infrastructure. The application demonstrates enterprise-level security practices including:

- **5-layer defense-in-depth architecture**
- **JWT-based stateless authentication**
- **Complete OWASP Top 10 mitigation**
- **Automated security testing suite (28 tests)**
- **Network isolation with 3-tier VPC design**
- **Encrypted data at rest**
- **AWS Systems Manager for secure access (no SSH keys)**

**Use Case:** User management system with secure CRUD operations, suitable for demonstrating DevSecOps security automation and cloud architecture best practices.

---

## Architecture

### High-Level Architecture Diagram
```
Internet
    |
    v
[Application Load Balancer] (Public Subnet - HTTP Port 80)
    |
    v
[EC2 - Flask API] (Private Web Subnet - Port 5000)
    |
    v
[RDS PostgreSQL] (Private Database Subnet - NO Internet Access)

Access: Developer → AWS SSM Session Manager → EC2 (No SSH, No Bastion)
```

### Network Architecture

**VPC Design:**
- CIDR: 10.0.0.0/16 (65,536 IP addresses)
- 3-tier network segmentation: public, private web, private database
- Multi-AZ deployment across us-east-2a and us-east-2b
**Subnets:**
- **Public Subnet (10.0.1.0/24):** Application Load Balancer only
- **Private Web Subnet (10.0.11.0/24):** EC2 instances running Flask
- **Private Database Subnet (10.0.21.0/24):** RDS PostgreSQL (isolated)

**Routing:**
- Public subnet → Internet Gateway (direct internet access)
- Private web subnet → NAT Gateway (outbound only for updates)
- Database subnet → No internet routes (complete isolation)

**Key Security Principles:** 
- Database has ZERO internet access - cannot be attacked directly from the internet
- EC2 instances in private subnet - no direct internet exposure
- Access via AWS Systems Manager Session Manager - no SSH keys or bastion hosts

---

## Security Controls

### Layer 1: Network Security

**VPC Architecture**
- 3-tier network design separates public-facing, application, and data layers
- Complete network isolation for database tier
- Security groups act as stateful firewalls at each tier

**Security Groups (Stateful Firewall Rules)**

1. **ALB Security Group:**
   - Inbound: Port 80 (HTTP) from 0.0.0.0/0 (public traffic)
   - Outbound: Port 5000 to Web Security Group only

2. **Web Security Group:**
   - Inbound: Port 5000 from ALB Security Group only
   - Outbound: Port 5432 to Database Security Group only
   - Outbound: Port 443 to 0.0.0.0/0 (for package updates and SSM communication)
   
   *Note: No SSH port (22) open - using AWS Systems Manager Session Manager for secure access*

3. **Database Security Group:**
   - Inbound: Port 5432 from Web Security Group only
   - Outbound: NONE (completely isolated)

**Network Isolation Benefits:**
- Database cannot be accessed from internet
- Application layer acts as security buffer
- EC2 instances not directly accessible (private subnet)
- Lateral movement between tiers prevented
- All traffic logged via VPC Flow Logs

**Access Management:**
- AWS Systems Manager Session Manager for EC2 access
- No SSH keys to manage or rotate
- No bastion host required (cost and security benefit)
- Works seamlessly with private subnets

---

### Layer 2: Application Security

**SQL Injection Prevention**
- All queries use psycopg2 parameterized statements
- User input passed as parameters, never concatenated into SQL strings
- Database driver handles escaping automatically

```python
# ❌ VULNERABLE (string concatenation)
query = f"SELECT * FROM users WHERE username = '{user_input}'"
cursor.execute(query)

# ✅ SECURE (parameterized query)
cursor.execute("SELECT * FROM users WHERE username = %s", (user_input,))
```

**Cross-Site Scripting (XSS) Prevention**
- JSON API responses only (no HTML rendering)
- All data returned as `application/json`
- Browsers cannot execute JavaScript in JSON responses

**Input Validation**
- Marshmallow schemas validate all user inputs
- Username: 3-50 characters, alphanumeric + underscore only
- Email: RFC 5322 compliant validation
- Password: Minimum 8 characters enforced
- All malformed requests rejected with 400/422 status codes

**Rate Limiting**
- 5 login attempts per minute per IP address
- HTTP 429 (Too Many Requests) returned after threshold
- Prevents brute force attacks
- Implemented with Flask-Limiter

**JWT Authentication**
- Stateless authentication using JSON Web Tokens
- Tokens signed with HS256 algorithm
- Short expiration times (configurable)
- HttpOnly cookies prevent JavaScript access

---

### Layer 3: Data Security

**Encryption at Rest**
- RDS: AES-256 encryption enabled
- EBS volumes: Encrypted with AWS-managed keys
- Database snapshots: Automatically encrypted

**Password Security**
- bcrypt hashing with 12 rounds (industry standard)
- Salted hashes - unique salt per password
- Passwords NEVER stored in plaintext
- Password fields never exposed in API responses

```python
# Password hashing
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=12))

# Password verification
bcrypt.checkpw(password.encode('utf-8'), stored_hash)
```

---

### Layer 4: Access Control

**Authentication**
- JWT-based stateless authentication
- All protected endpoints require valid token
- Tokens include user identity claims
- Invalid/expired tokens rejected with 401/422

**Authorization**
- Users can only access their own resources
- Database queries filtered by authenticated user ID
- Principle of least privilege enforced

**Session Security**
- HttpOnly flag prevents JavaScript access to tokens
- Session timeout after inactivity period
- Last login timestamp tracked for security auditing

**IAM Roles (AWS)**
- EC2 instances use IAM roles (no hardcoded credentials)
- `AmazonSSMManagedInstanceCore` policy for Session Manager access
- RDS credentials stored as environment variables (minimal permissions)

---

### Layer 5: Monitoring & Incident Response

**Application Logging**
- All authentication attempts logged
- Failed login attempts tracked per IP
- API endpoint access logged with timestamps
- Error rates and response times monitored

**Session Manager Logging**
- Complete audit trail of who accessed what and when
- Session recordings available for compliance
- No SSH key management overhead

**Metrics Tracked**
- Request rate and error rate
- Response times (p50, p95, p99)
- Database connection pool usage
- Failed authentication attempts by IP
- Last login timestamps per user

---

## OWASP Top 10 Coverage

| OWASP Risk | Mitigation Strategy | Implementation |
|------------|---------------------|----------------|
| **A01: Broken Access Control** | JWT authentication + authorization | Token-based auth, user-scoped queries |
| **A02: Cryptographic Failures** | Encryption at rest | RDS/EBS encryption, bcrypt password hashing |
| **A03: Injection** | Parameterized queries | psycopg2 parameterized statements |
| **A04: Insecure Design** | Defense-in-depth architecture | 5 security layers, network isolation |
| **A05: Security Misconfiguration** | Hardened configuration | IMDSv2, minimal IAM, SSM access only |
| **A06: Vulnerable Components** | Dependency management | Pinned versions in requirements.txt |
| **A07: Authentication Failures** | Rate limiting + strong hashing | 5 attempts/min limit, bcrypt (12 rounds) |
| **A08: Software/Data Integrity** | Secure JWT handling | Signed tokens, HttpOnly cookies |
| **A09: Security Logging Failures** | Comprehensive logging | VPC Flow Logs, app logs, SSM logs|
| **A10: SSRF** | Network segmentation | Private subnets, no outbound from database |

---

## Security Testing

See [SECURITY_TESTING.md](SECURITY_TESTING.md) for complete test suite documentation.

### Test Summary

**28 automated tests** validating all security controls:

| Category | Tests | Pass Rate |
|----------|-------|-----------|
| Basic Connectivity | 1 | 100% |
| User Registration | 3 | 100% |
| Authentication | 3 | 100% |
| JWT Authorization | 3 | 100% |
| Password Management | 3 | 100% |
| User Deletion | 5 | 100% |
| Input Validation | 3 | 100% |
| Security Hardening | 7 | 100% |
| **TOTAL** | **28** | **100%** |

### Key Security Validations

✅ **SQL Injection:** Prevented by architecture (psycopg2 parameterized queries)  
✅ **XSS:** Prevented by architecture (JSON responses only)  
✅ **Rate Limiting:** HTTP 429 triggered after 5 login attempts  
✅ **Authentication:** Invalid credentials properly rejected (401)  
✅ **Authorization:** Protected endpoints require valid JWT  
✅ **Password Security:** Passwords never exposed in responses  
✅ **Input Validation:** Invalid formats rejected (400/422)  

**Run tests:**
```bash
chmod +x security_tests.sh
./security_tests.sh
```

---

## Technologies Used

### Infrastructure
- **Cloud Provider:** AWS (us-east-2)
- **Compute:** EC2 (t3.micro, Ubuntu 22.04)
- **Database:** RDS PostgreSQL 15
- **Load Balancer:** Application Load Balancer (ALB)
- **Networking:** VPC, Subnets, Security Groups, NAT Gateway
- **Access Management:** AWS Systems Manager Session Manager (no SSH)

### Application Stack
- **Language:** Python 3.11
- **Framework:** Flask 3.0
- **Database Driver:** psycopg2 (PostgreSQL)
- **Authentication:** Flask-JWT-Extended
- **Password Hashing:** bcrypt (12 rounds)
- **Rate Limiting:** Flask-Limiter (Redis backend)
- **Input Validation:** Marshmallow schemas
- **CORS:** Flask-CORS

### Security Tools
- **Testing:** Custom bash script (28 automated tests)
- **Static Analysis:** Bandit (Python security linter)
- **Dependency Scanning:** Safety (checks for known CVEs)

---

## Deployment

### Prerequisites
- AWS account with appropriate permissions
- AWS CLI configured with SSM permissions
- SSM Agent installed on EC2 (pre-installed on Ubuntu 22.04)
- PostgreSQL client (for database verification)

### Infrastructure Setup

1. **Create VPC and Subnets**
   - VPC: 10.0.0.0/16
   - Public subnet: 10.0.1.0/24
   - Private web subnet: 10.0.11.0/24
   - Private database subnet: 10.0.21.0/24

2. **Configure Networking**
   - Create Internet Gateway
   - Create NAT Gateway in public subnet
   - Configure route tables for each subnet tier

3. **Set Up Security Groups**
   - ALB security group (port 80 inbound)
   - Web security group (port 5000 from ALB, port 443 outbound for SSM)
   - Database security group (port 5432 from web tier)
   - *Note: No port 22 (SSH) needed*

4. **Create IAM Role for EC2**
   - Attach `AmazonSSMManagedInstanceCore` policy
   - Enables Systems Manager Session Manager access

5. **Launch RDS Instance**
   - Engine: PostgreSQL 15
   - Instance class: db.t3.micro
   - Storage: 20GB GP3 encrypted
   - Multi-AZ: Disabled (dev) / Enabled (production)
   - Backup retention: 7 days

6. **Launch EC2 Instance**
   - AMI: Ubuntu 22.04 LTS
   - Instance type: t3.micro
   - Subnet: Private web subnet
   - Security group: Web security group
   - IAM role: EC2-SSM-Role (created in step 4)
   - User data: Install Python, Flask, dependencies

7. **Deploy Application**
   ```bash
   # Connect to EC2 instance via AWS Systems Manager Session Manager
   aws ssm start-session --target <instance-id>
   
   # OR use AWS Console:
   # EC2 → Instances → Select instance → Connect → Session Manager → Connect
   
   # Once connected, clone repository
   git clone <your-repo-url>
   cd secure-aws-app
   
   # Install dependencies
   pip install -r requirements.txt
   
   # Set environment variables
   export DB_HOST=<rds-endpoint>
   export DB_NAME=webapp_db
   export DB_USER=admin
   export DB_PASSWORD=<secure-password>
   export JWT_SECRET_KEY=<random-secret>
   
   # Run application
   python app.py
   ```

8. **Configure ALB**
   - Create target group (port 5000, HTTP protocol)
   - Register EC2 instance as target
   - Create listener (port 80 HTTP → target group)
   - Configure health checks (/healthCheck endpoint)

### EC2 Instance Connection Configuration

**IAM Role for SSM Access:**
1. Create IAM role with `AmazonSSMManagedInstanceCore` policy
2. Attach role to EC2 instance during launch
3. This enables Systems Manager Session Manager without SSH keys


**Connect to instance:**
```bash
# Using AWS Cloudshell
aws ssm start-session --target i-<instance-id>
```

### Application Configuration

**Environment Variables:**
```bash
DB_HOST=<rds-endpoint>
DB_NAME=webapp_db
DB_USER=admin
DB_PASSWORD=<secure-password>
JWT_SECRET_KEY=<random-256-bit-secret>
FLASK_ENV=production
```

**Database Schema:**
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    last_login TIMESTAMP
);
```

---
## API Endpoints

### Public Endpoints
- `GET /healthCheck` - Health check for ALB

### Authentication
- `POST /api/register` - Create new user account
- `POST /login` - Authenticate and receive JWT token

### Protected Endpoints (Require JWT)
- `GET /api/users/me` - Get current user information
- `PUT /api/users/me/password` - Update user password
- `DELETE /api/users/me` - Delete user account
