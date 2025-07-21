# GOIT Project Infrastructure (Terraform)

Цей репозиторій містить інфраструктуру для Fullstack-додатку, що включає:

- 🖼️ Статичний frontend (React) — розміщено в Amazon S3 з публічним доступом
- 🧠 Backend API — працює на ECS Fargate
- 💾 PostgreSQL — RDS з приватним доступом
- 🌐 ALB (Application Load Balancer)
- 🔁 Auto Scaling ECS Service
- 🔐 IAM ролі, SSM параметри
- 🔧 CloudWatch логи
- 🏗️ Повністю керовано через Terraform

## 📁 Структура
terraform/
│
├── main.tf # Основні модулі / виклики
├── vpc.tf # VPC, сабнети, Internet Gateway
├── ecs.tf # ECS Cluster, Task Definition, Service
├── rds.tf # RDS PostgreSQL інстанс
├── alb.tf # ALB, Target Groups, Listeners
├── s3.tf # S3 бакет для frontend
├── ssm.tf # Параметри середовища (SSM)
├── outputs.tf # Головні вихідні значення
├── sg.tf # Security Groups
├── nat-instance.tf # NAT instance в якості альтернативи NAT Gateway
├── locals.tf # Локальні значення (теги, ідентифікатори)

## 🚀 Деплой

1. **Підготуй AWS профіль** (наприклад `goit`):

```bash
aws configure --profile goit
```
2**Ініціалізуй Terraform**
```bash
terraform init
```
3**Ініціалізуй Terraform**
```bash
terraform plan
```
4**Ініціалізуй Terraform**
```bash
terraform apply
```

🖼️ Frontend (React App)
React-застосунок має бути зібраний та скопійований у S3:
```bash
npm run build  # або yarn build
aws s3 sync dist/ s3://goit-project/ --delete
```
📡 Backend API
Запускається в ECS (Fargate)
Підключено до ALB
Розгортається за допомогою Docker + ECR
Використовується healthcheck /api/categories.

🧩 Залежності
Terraform ≥ 1.5
AWS CLI
