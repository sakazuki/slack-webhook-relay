#!/bin/bash

set -e

echo "=== OCI Functions Deployment ==="

# 必要な変数のチェック
if [ -z "$OCI_REGION" ] || [ -z "$OCI_TENANCY_NAMESPACE" ] || [ -z "$COMPARTMENT_ID" ] || [ -z "$TENANCY_OCID" ]; then
    echo "Error: Required environment variables are not set."
    echo "Please set: OCI_REGION, OCI_TENANCY_NAMESPACE, COMPARTMENT_ID, TENANCY_OCID"
    exit 1
fi

if [ -z "$SUBNET_ID" ] || [ -z "$GATEWAY_SUBNET_ID" ]; then
    echo "Error: Network-related environment variables are not set."
    echo "Please set: SUBNET_ID, GATEWAY_SUBNET_ID"
    exit 1
fi

# 作業ディレクトリへ移動
cd "$(dirname "$0")"

# 依存関係のインストール
echo "Installing dependencies..."
cd src
npm install --production
cd ..

# Dockerイメージのビルド
echo "Building Docker image..."
IMAGE_TAG="${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/slack-webhook-relay-repo:latest"
docker build -t "$IMAGE_TAG" .

# OCIRへのログイン
echo "Logging in to OCIR..."
echo "Please enter your OCIR username and auth token when prompted."
docker login "${OCI_REGION}.ocir.io"

# イメージのプッシュ
echo "Pushing Docker image to OCIR..."
docker push "$IMAGE_TAG"

# Terraform初期化
echo "Initializing Terraform..."
cd terraform/oci
terraform init

# 変数ファイルの作成
cat > terraform.tfvars <<EOF
oci_region          = "$OCI_REGION"
compartment_id      = "$COMPARTMENT_ID"
tenancy_ocid        = "$TENANCY_OCID"
tenancy_namespace   = "$OCI_TENANCY_NAMESPACE"
subnet_ids          = ["$SUBNET_ID"]
gateway_subnet_id   = "$GATEWAY_SUBNET_ID"
EOF

# プランの確認
echo "Planning deployment..."
terraform plan

# ユーザー確認
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# デプロイ実行
echo "Deploying to OCI Functions..."
terraform apply -auto-approve

# 出力の表示
echo ""
echo "=== Deployment Complete ==="
terraform output

echo ""
echo "To get the API endpoint:"
echo "  terraform output api_endpoint"
