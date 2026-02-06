#!/bin/bash

set -e

echo "=== AWS Lambda Deployment ==="

# 作業ディレクトリへ移動
cd "$(dirname "$0")/terraform/aws"

# 依存関係のインストール
echo "Installing dependencies..."
cd ../../src
npm install --production
cd ../terraform/aws

# Terraform初期化
echo "Initializing Terraform..."
terraform init

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
echo "Deploying to AWS Lambda..."
terraform apply -auto-approve

# 出力の表示
echo ""
echo "=== Deployment Complete ==="
terraform output

echo ""
echo "To get the Function URL:"
echo "  terraform output function_url"
