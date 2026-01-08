A fully serverless Task Management System backend built on AWS using Terraform and AWS Lambda.
This project demonstrates clean infrastructure design, least-privilege security, and production-ready serverless APIs.

🚀 Features

- Serverless REST API (GET / POST)
- Task creation and retrieval
- List all tasks (optional pagination)
- Input validation & structured error handling
- DynamoDB as primary datastore
- Least-privilege IAM roles
- Infrastructure as Code (Terraform)
- Centralized logging with CloudWatch
- Consistent naming conventions & tagging

🏗️ Architecture

Flow:
- Client sends HTTP requests
- API Gateway (or Lambda Function URL) receives the request
- AWS Lambda processes business logic
- DynamoDB stores and retrieves tasks
- CloudWatch captures logs & metrics
- Terraform manages all infrastructure
- Core AWS Services Used:
- AWS Lambda
- Amazon API Gateway (or Function URLs)
- Amazon DynamoDB
- AWS IAM
- Amazon CloudWatch
- Terraform Cloud

📦 Data Model
Field	Type	Description
task_id	String	Primary key (UUID)
title	String	Task title
description	String	Task description
status	String	pending, in_progress, completed
created_at	String	ISO-8601 timestamp
updated_at	String	ISO-8601 timestamp
🔌 API Endpoints
➕ Create Task


🔐 Security

- Least-privilege IAM roles per Lambda
- No hardcoded credentials
- AWS SSO for authentication
- Principle of least access applied to DynamoDB & CloudWatch

🛠️ Tech Stack

Runtime: Node.js / Python (AWS Lambda)
Infrastructure: Terraform
Database: Amazon DynamoDB
API: API Gateway or Lambda Function URLs
Logging: Amazon CloudWatch

📁 Project Structure
.
├── terraform/
│   ├── main.tf
│   ├── iam.tf
│   ├── dynamodb.tf
│   ├── lambda.tf
│   ├── api.tf
│   └── variables.tf
├── lambdas/
│   ├── create_task/
│   │   ├── handler.js
│   │   └── package.json
│   ├── get_task/
│   │   ├── handler.js
│   │   └── package.json
├── scripts/
│   └── build.sh
└── README.md

🚀 Deployment

Prerequisites
AWS Account (via AWS SSO)
Terraform CLI installed
Node.js or Python installed

Steps
terraform init
terraform plan
terraform apply
Once deployed, Terraform outputs the API endpoint URL.

📊 Monitoring & Logging

All Lambda logs stored in CloudWatch
Errors and invocation metrics tracked automatically
Structured logging for easier debugging

🧪 Improvements & Future Work

Add authentication (Cognito / IAM auth)
Add update & delete endpoints
Add DynamoDB GSIs for filtering
Add CI/CD pipeline (GitHub Actions)

Add request throttling & WAF

👤 Author
Vaishnavi Budala Shridhara
Cloud / Backend Engineer
🚀 AWS • Terraform • Serverless
