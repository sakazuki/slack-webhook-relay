# Webhook Relay - JSON to YAML Converter

Slack Webhook通知用のJSON→YAML変換中継API。アラート通知のJSONペイロードを読みやすいYAML形式に変換してSlackへ送信します。

## 特徴

- **JSONをYAMLに自動変換**: アラート内容の可読性を向上
- **複数Webhook対応**: クエリパラメータで送信先を動的に指定
- **マルチクラウド**: AWS LambdaとOCI Functionsの両方にデプロイ可能
- **Infrastructure as Code**: Terraformで完全自動化

## アーキテクチャ

```
アラートシステム → [API Gateway] → [Lambda/Functions] → [Slack Webhook]
                       ↓
                  JSONをYAMLに変換
```

## クイックスタート

### AWS Lambdaへのデプロイ

```bash
# 依存関係のインストール
cd src
npm install

# デプロイスクリプトの実行
cd ..
./deploy-aws.sh

# または手動でTerraform実行
cd terraform/aws
terraform init
terraform plan
terraform apply
```

### OCI Functionsへのデプロイ

```bash
# 環境変数の設定
export OCI_REGION="ap-tokyo-1"
export OCI_TENANCY_NAMESPACE="your-tenancy-namespace"
export COMPARTMENT_ID="ocid1.compartment.oc1..xxxxx"
export SUBNET_IDS='["ocid1.subnet.oc1..xxxxx"]'
export GATEWAY_SUBNET_ID="ocid1.subnet.oc1..xxxxx"

# デプロイスクリプトの実行
./deploy-oci.sh

# または手動でデプロイ
docker build -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/webhook-relay-repo:latest .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/webhook-relay-repo:latest

cd terraform/oci
terraform init
terraform apply
```

## 使い方

### 基本的な使用例

```bash
# JSON形式のアラートを送信
curl -X POST "https://api.example.com/webhooks?d=https://hooks.slack.com/services/YOUR/WEBHOOK/PATH" \
  -H "Content-Type: application/json" \
  -d '{
    "alert": "High CPU Usage",
    "severity": "warning",
    "host": "web-server-01",
    "cpu_usage": 85.3,
    "timestamp": "2025-02-07T10:30:00Z"
  }'
```

### Slackでの表示

**変換前 (通常のJSON送信)**
```
{"alert":"High CPU Usage","severity":"warning","host":"web-server-01","cpu_usage":85.3,"timestamp":"2025-02-07T10:30:00Z"}
```

**変換後 (このAPIを使用)**
```yaml
alert: High CPU Usage
severity: warning
host: web-server-01
cpu_usage: 85.3
timestamp: '2025-02-07T10:30:00Z'
```

### プレーンテキストの送信

```bash
# プレーンテキストもそのまま送信可能
curl -X POST "https://api.example.com/webhooks?d=https://hooks.slack.com/services/YOUR/WEBHOOK/PATH" \
  -H "Content-Type: text/plain" \
  -d "サーバーが正常に起動しました"
```

## API仕様

### エンドポイント

```
POST /webhooks
```

### クエリパラメータ

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| d | ✓ | 送信先のSlack Webhook URL | `https://hooks.slack.com/services/XXX/YYY/ZZZ` |

### リクエストボディ

- **Content-Type**: `application/json` または `text/plain`
- JSON形式の場合は自動的にYAMLに変換されます
- プレーンテキストの場合はそのまま送信されます

### レスポンス

**成功時 (200 OK)**
```json
{
  "message": "Successfully sent to Slack",
  "converted": true,
  "destination": "https://hooks.slack.com/***"
}
```

**エラー時 (400 Bad Request)**
```json
{
  "error": "Missing required parameter: d (destination webhook URL)"
}
```

## 監視アラートとの連携例

### Prometheus Alertmanager

```yaml
receivers:
  - name: 'slack-webhook-relay'
    webhook_configs:
      - url: 'https://api.example.com/webhooks?d=https://hooks.slack.com/services/XXX/YYY/ZZZ'
        send_resolved: true
```

### Grafana

```json
{
  "type": "webhook",
  "url": "https://api.example.com/webhooks?d=https://hooks.slack.com/services/XXX/YYY/ZZZ",
  "httpMethod": "POST"
}
```

### CloudWatch Alarms (AWS)

SNS → Lambda → Webhook Relay → Slack の構成で連携可能

## Terraform変数

### AWS Lambda

| 変数名 | デフォルト | 説明 |
|--------|-----------|------|
| aws_region | ap-northeast-1 | AWSリージョン |
| function_name | webhook-relay | Lambda関数名 |
| lambda_timeout | 30 | タイムアウト(秒) |
| lambda_memory_size | 256 | メモリサイズ(MB) |
| enable_api_key | false | APIキー認証の有効化 |
| log_retention_days | 14 | ログ保持期間(日) |

### OCI Functions

| 変数名 | デフォルト | 説明 |
|--------|-----------|------|
| oci_region | ap-tokyo-1 | OCIリージョン |
| function_name | webhook-relay | 関数名 |
| function_timeout | 30 | タイムアウト(秒) |
| function_memory_mb | 256 | メモリサイズ(MB) |
| enable_rate_limiting | false | レート制限の有効化 |
| log_retention_days | 14 | ログ保持期間(日) |

## セキュリティ

### Webhook URLの検証

- Slack公式のWebhook URLのみ許可
- URLのバリデーションを実装済み

### レート制限

AWS:
```hcl
variable "enable_api_key" {
  default = true
}
variable "api_rate_limit" {
  default = 100  # リクエスト/秒
}
```

OCI:
```hcl
variable "enable_rate_limiting" {
  default = true
}
variable "rate_limit_rps" {
  default = 100
}
```

### ログ管理

- すべてのリクエストをCloudWatch Logs/OCI Loggingに記録
- Webhook URLは部分的にマスキング
- エラーログの詳細記録

## トラブルシューティング

### Lambda デプロイエラー

```bash
# ZIPファイルのサイズを確認
du -h terraform/aws/webhook-relay.zip

# 依存関係を再インストール
cd src
rm -rf node_modules
npm install --production
```

### OCI Functions イメージプッシュエラー

```bash
# OCIRへの認証を再実行
docker login ${OCI_REGION}.ocir.io

# イメージのビルドとプッシュを再実行
docker build -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/webhook-relay-repo:latest .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/webhook-relay-repo:latest
```

### Slack送信エラー

```bash
# ログの確認 (AWS)
aws logs tail /aws/lambda/webhook-relay --follow

# ログの確認 (OCI)
oci logging-search search-logs \
  --search-query "search \"<log-group-id>\" | sort by datetime desc"
```

## コスト見積もり

### AWS Lambda

- リクエスト: 100万件/月 → 約$0.20
- 実行時間: 30秒、256MB → 約$0.83
- API Gateway: 100万リクエスト → 約$3.50
- **合計**: 約$4.53/月

### OCI Functions

- リクエスト: 100万件/月 → 約$0.20
- 実行時間: 30秒、256MB → 約$0.60
- API Gateway: 100万リクエスト → 約$3.00
- **合計**: 約$3.80/月

## ライセンス

MIT

## サポート

Issue報告やプルリクエストを歓迎します。
