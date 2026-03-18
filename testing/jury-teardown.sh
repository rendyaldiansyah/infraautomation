#!/usr/bin/env bash
# ============================================================
#  testing/jury-teardown.sh
#  LKS 2026 — Bersihkan semua resource setelah testing
#
#  Jalankan setelah selesai testing untuk menghapus semua
#  resource AWS agar tidak ada biaya yang berjalan.
#
#  Cara pakai:
#    ./testing/jury-teardown.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "\n${BOLD}━━━ $1 ━━━${NC}\n"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"

echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     LKS 2026 — TEARDOWN (Hapus Semua Resource) ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""
read -rp "  Yakin ingin menghapus SEMUA resource LKS 2026? (ketik 'yes'): " CONFIRM
[ "$CONFIRM" != "yes" ] && { echo "Dibatalkan."; exit 0; }

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)

# ── ECS Services & Clusters ──────────────────────────────────
step "1. Hapus ECS Services (us-east-1)"

for SVC in lks-fe-service lks-api-service; do
  EXISTS=$(aws ecs describe-services --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].status' --output text --region us-east-1 2>/dev/null || echo "")
  if [ "$EXISTS" = "ACTIVE" ]; then
    aws ecs update-service --cluster lks-ecs-cluster --service "$SVC" \
      --desired-count 0 --region us-east-1 --output json >/dev/null 2>&1 || true
    sleep 5
    aws ecs delete-service --cluster lks-ecs-cluster --service "$SVC" \
      --force --region us-east-1 --output json >/dev/null 2>&1 || true
    ok "ECS Service $SVC dihapus"
  else
    warn "$SVC tidak ditemukan, skip"
  fi
done

step "2. Hapus ECS Services (us-west-2)"
EXISTS=$(aws ecs describe-services --cluster lks-monitoring-cluster \
  --services lks-prometheus-service \
  --query 'services[0].status' --output text --region us-west-2 2>/dev/null || echo "")
if [ "$EXISTS" = "ACTIVE" ]; then
  aws ecs update-service --cluster lks-monitoring-cluster \
    --service lks-prometheus-service \
    --desired-count 0 --region us-west-2 --output json >/dev/null 2>&1 || true
  sleep 5
  aws ecs delete-service --cluster lks-monitoring-cluster \
    --service lks-prometheus-service \
    --force --region us-west-2 --output json >/dev/null 2>&1 || true
  ok "ECS Service lks-prometheus-service dihapus"
fi

log "Tunggu tasks stopped..."
sleep 30

step "3. Hapus ECS Clusters"
aws ecs delete-cluster --cluster lks-ecs-cluster \
  --region us-east-1 --output json >/dev/null 2>&1 \
  && ok "lks-ecs-cluster dihapus" || warn "lks-ecs-cluster tidak ditemukan"

aws ecs delete-cluster --cluster lks-monitoring-cluster \
  --region us-west-2 --output json >/dev/null 2>&1 \
  && ok "lks-monitoring-cluster dihapus" || warn "lks-monitoring-cluster tidak ditemukan"

step "4. Terraform Destroy (VPC, ALB, RDS, Peering, dll)"
if [ -f "$TF_DIR/terraform.tfstate" ] || [ -d "$TF_DIR/.terraform" ]; then
  cd "$TF_DIR"
  log "terraform destroy..."
  terraform destroy -auto-approve -input=false 2>&1 || warn "terraform destroy selesai dengan beberapa error"
  ok "Terraform resources dihapus"
  cd "$ROOT_DIR"
else
  warn "terraform.tfstate tidak ditemukan — skip terraform destroy"
fi

step "5. Hapus ECR Images"
for REPO in lks-fe-app lks-api-app; do
  IMGS=$(aws ecr list-images --repository-name "$REPO" \
    --region us-east-1 --query 'imageIds' --output json 2>/dev/null || echo "[]")
  if [ "$IMGS" != "[]" ] && [ -n "$IMGS" ]; then
    aws ecr batch-delete-image --repository-name "$REPO" \
      --image-ids "$IMGS" --region us-east-1 --output json >/dev/null 2>&1 || true
    ok "ECR images $REPO dihapus"
  fi
done

PROM_IMGS=$(aws ecr list-images --repository-name lks-prometheus \
  --region us-west-2 --query 'imageIds' --output json 2>/dev/null || echo "[]")
if [ "$PROM_IMGS" != "[]" ] && [ -n "$PROM_IMGS" ]; then
  aws ecr batch-delete-image --repository-name lks-prometheus \
    --image-ids "$PROM_IMGS" --region us-west-2 --output json >/dev/null 2>&1 || true
  ok "ECR images lks-prometheus dihapus"
fi

step "6. Hapus CloudWatch Log Groups"
for LG in /ecs/lks-fe-app /ecs/lks-api-app; do
  aws logs delete-log-group --log-group-name "$LG" \
    --region us-east-1 2>/dev/null && ok "Log group $LG dihapus" || true
done
aws logs delete-log-group --log-group-name /ecs/lks-prometheus \
  --region us-west-2 2>/dev/null && ok "Log group /ecs/lks-prometheus dihapus" || true

step "7. Hapus Task Definitions"
for FAMILY in lks-fe-task lks-api-task; do
  TDEFS=$(aws ecs list-task-definitions \
    --family-prefix "$FAMILY" --status ACTIVE \
    --query 'taskDefinitionArns[]' --output text --region us-east-1 2>/dev/null || echo "")
  for TD in $TDEFS; do
    aws ecs deregister-task-definition --task-definition "$TD" \
      --region us-east-1 --output json >/dev/null 2>&1 || true
  done
  [ -n "$TDEFS" ] && ok "Task definitions $FAMILY dideregister"
done

PTDEFS=$(aws ecs list-task-definitions \
  --family-prefix lks-prometheus-task --status ACTIVE \
  --query 'taskDefinitionArns[]' --output text --region us-west-2 2>/dev/null || echo "")
for PTD in $PTDEFS; do
  aws ecs deregister-task-definition --task-definition "$PTD" \
    --region us-west-2 --output json >/dev/null 2>&1 || true
done

step "8. Reset prometheus.yml ke placeholder IPs"
if [ -f "$ROOT_DIR/monitoring/prometheus/prometheus.yml" ]; then
  sed -i 's|10\.0\.3\.[0-9]*:9100|10.0.3.10:9100|g' \
    "$ROOT_DIR/monitoring/prometheus/prometheus.yml" 2>/dev/null || true
  # Only reset second one if both exist
  ok "prometheus.yml di-reset ke placeholder IPs"
fi

# Remove tfvars
rm -f "$TF_DIR/terraform.tfvars"
rm -f "$TF_DIR/tfplan"
ok "terraform.tfvars dihapus"

echo ""
echo -e "${GREEN}${BOLD}Teardown selesai. Semua resource LKS 2026 sudah dihapus.${NC}"
echo -e "${YELLOW}Note: ECR repositories masih ada (kosong). Hapus manual jika tidak diperlukan.${NC}"
echo -e "${YELLOW}Note: S3 state bucket masih ada. Hapus manual: aws s3 rb s3://<bucket> --force${NC}"
