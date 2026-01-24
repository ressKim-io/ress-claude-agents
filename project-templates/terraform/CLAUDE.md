# Terraform Project - Claude Settings

## Quick Reference
- Format: `terraform fmt -recursive`
- Validate: `terraform validate`
- Plan: `terraform plan -out=tfplan`
- Security: `tfsec .`

## Project Structure
```
modules/{vpc,eks,rds}/   # Reusable modules
envs/{dev,staging,prod}/ # Environment configs
global/{iam,dns}/        # Global resources
```

## CRITICAL Rules

1. **State Backend** - Verify: `grep "backend" envs/*/backend.tf`
   ```hcl
   backend "s3" {
     bucket         = "company-terraform-state"
     encrypt        = true
     dynamodb_table = "terraform-state-lock"
   }
   ```

2. **Sensitive Variables** - Verify: `grep "sensitive" variables.tf`
   ```hcl
   variable "db_password" {
     type      = string
     sensitive = true
   }
   ```

3. **No Hardcoded Secrets** - Verify: `grep -r "password\s*=" .`
   ```hcl
   # Use Secrets Manager
   data "aws_secretsmanager_secret_version" "db" {
     secret_id = "prod/db/password"
   }
   ```

## Common Mistakes

| Mistake | Correct | Verify |
|---------|---------|--------|
| `Action: "*"` | Specific actions | `grep 'Action.*\*'` |
| `0.0.0.0/0` ingress | Restricted CIDR | `grep "0.0.0.0/0"` |
| No encryption | Enable KMS | `grep "encrypted"` |
| No variable validation | Add validation block | `grep "validation"` |
| No state locking | Use DynamoDB | Check backend.tf |

## Skills Reference
- `/terraform-modules` - Module development patterns
- `/terraform-security` - Security best practices

## Commands
- `/plan-review` - Analyze terraform plan
- `/security` - tfsec security scan
- `/module-gen` - Generate module scaffold
- `/validate` - Best practice validation

---
*Applies with global CLAUDE.md settings*
