# Project: Microservice Deployment with CI/CD & Inter-Region VPC Peering

### Multi-Region Architecture

```
us-east-1 (N. Virginia) — Application                us-west-2 (Oregon) — Monitoring
┌──────────────────────────────────────────┐          ┌────────────────────────────────┐
│  Public Subnet (10.0.1-2.0/24)           │          │  Private Subnet (10.1.1-2.0/24)│
│  ├── ALB :80                             │          │  ├── Prometheus     :9090       │
│  └── NAT Gateway                         │          │  ├── Grafana        :3000       │
│                                          │          │  ├── Loki           :3100       │
│  Private Subnet (10.0.3-4.0/24) ECS      │◄────────►│  └── Alertmanager  :9093       │
│  ├── lks-fe-service       :3000          │  Inter-   │                                │
│  ├── lks-api-service      :8080          │  Region   │  No IGW · No NAT               │
│  └── lks-analytics-service :5000/:9100   │  Peering  │  VPC Endpoints only            │
│                                          │  (enc.)   │  ECR us-west-2                 │
│  Isolated Subnet (10.0.5-6.0/24)         │          └────────────────────────────────┘
│  ├── RDS PostgreSQL  :5432               │
│  ├── DynamoDB                            │
│  └── SQS                                 │
└──────────────────────────────────────────┘
```

### Repository Structure

```
infralks26/
├── frontend/              React 18 + Vite + Tailwind CSS
├── api/                   Node.js Express REST API (CRUD + SQS events)
├── analytics/             Python FastAPI — stats + Prometheus /metrics
├── monitoring/            Prometheus, Grafana, Loki, Alertmanager configs
├── terraform/             IaC scaffold — contestants write the .tf files
│   ├── backend.tf         S3 remote state backend configuration
│   ├── variables.tf       All input variable definitions
│   ├── main.tf            Root module: two providers + module calls
│   ├── outputs.tf         ALB DNS, ECR URLs, peering ID, etc.
│   └── modules/           Nine modules — one per resource group
└── .github/workflows/     lks-cicd.yml — 4-job CI/CD pipeline
```

### Key Inter-Region Peering Facts

| | Same-Region | Inter-Region (this project) |
|---|---|---|
| `peer_region` | Not needed | **Required** |
| `auto_accept` | Works | **Not supported — use aws_vpc_peering_connection_accepter** |
| DNS resolution | Supported | **Not supported — use private IPs only** |
| Encryption | Optional | **Automatic** |
| ECR | One registry | **One per region** |

### CI/CD Pipeline — 4 Jobs

```
git push → install → build_and_push_ecr → upload_to_s3 → deploy
                     ↳ ECR us-east-1                ↳ terraform apply
                     ↳ ECR us-west-2                   (both regions)
```

### Getting Started

```bash
# 1. Clone and push to your GitHub account
git init && git add . && git commit -m "Initial commit"
git remote add origin https://github.com/<you>/infralks26.git
git push -u origin main

# 2. Follow .github/SETUP.md for Secrets configuration

# 3. Create S3 state bucket manually (one-time)
aws s3 mb s3://lks-tfstate-yourname-2026 --region us-east-1

# 4. Write your Terraform modules (see terraform/modules/*/README.md)

# 5. Push to trigger the pipeline
git push origin main
```

### Local Development

```bash
# Run all services locally with Docker Compose
docker compose up -d
open http://localhost:3000
```
