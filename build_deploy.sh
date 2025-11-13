#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$ROOT_DIR/infra"

echo "==> Creating lambda zip packages via Terraform archive_file when applying..."
# The archive_file data sources create the zips during `terraform apply`,
# so we don't build here. If you prefer manual zips, uncomment:
#   (cd lambdas/write && zip -r ../write.zip .)
#   (cd lambdas/read && zip -r ../read.zip .)

pushd "$INFRA_DIR" >/dev/null

terraform init -upgrade
terraform validate
terraform plan -out tfplan
terraform apply -auto-approve tfplan

popd >/dev/null

echo "==> Done. API base URL:"
terraform -chdir="$INFRA_DIR" output api_endpoint
