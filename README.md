# Webhook Relay - JSON to YAML Converter

Slack Webhook通知用のJSON→YAML変換中継API。アラート通知のJSONペイロードを読みやすいYAML形式に変換してSlackへ送信します。

## 特徴

- **JSONをYAMLに自動変換**: アラート内容の可読性を向上
- **複数Webhook対応**: クエリパラメータで送信先を動的に指定
- **マルチクラウド**: AWS LambdaとOCI Functionsの両方にデプロイ可能
- **Infrastructure as Code**: Terraformで完全自動化

## アーキテクチャ

```
アラートシステム → [Lambda Function URL] → [Lambda] → [Slack Webhook]
                       ↓
                  JSONをYAMLに変換
```

AWS版はLambda Function URLを使用したシンプルな構成です。API Gatewayを使わないため、より低コストで運用できます。

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

# Function URLの確認
terraform output function_url
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
docker build -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/slack-webhook-relay-repo:latest .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/slack-webhook-relay-repo:latest

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
timestamp: "2025-02-07T10:30:00Z"
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

| パラメータ | 必須 | 説明                      | 例                                             |
| ---------- | ---- | ------------------------- | ---------------------------------------------- |
| d          | ✓    | 送信先のSlack Webhook URL | `https://hooks.slack.com/services/XXX/YYY/ZZZ` |

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
  - name: "slack-webhook-relay"
    webhook_configs:
      - url: "https://api.example.com/webhooks?d=https://hooks.slack.com/services/XXX/YYY/ZZZ"
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

| 変数名             | デフォルト          | 説明             |
| ------------------ | ------------------- | ---------------- |
| aws_region         | ap-northeast-1      | AWSリージョン    |
| function_name      | slack-webhook-relay | Lambda関数名     |
| lambda_timeout     | 30                  | タイムアウト(秒) |
| lambda_memory_size | 256                 | メモリサイズ(MB) |
| log_retention_days | 14                  | ログ保持期間(日) |

### OCI Functions

| 変数名               | デフォルト          | 説明               |
| -------------------- | ------------------- | ------------------ |
| oci_region           | ap-tokyo-1          | OCIリージョン      |
| function_name        | slack-webhook-relay | 関数名             |
| function_timeout     | 30                  | タイムアウト(秒)   |
| function_memory_mb   | 256                 | メモリサイズ(MB)   |
| enable_rate_limiting | false               | レート制限の有効化 |
| log_retention_days   | 14                  | ログ保持期間(日)   |

## セキュリティ

### Webhook URLの検証

- Slack公式のWebhook URLのみ許可
- URLのバリデーションを実装済み

### CORS設定

AWS Lambda Function URLでは、以下のCORS設定を適用:

- POST メソッドのみ許可
- 必要最小限のヘッダーのみ許可

### レート制限

OCI:

```hcl
variable "enable_rate_limiting" {
  default = true
}
variable "rate_limit_rps" {
  default = 100
}
```

AWS Lambda Function URLではネイティブなレート制限機能はありませんが、必要に応じてLambda関数内でのレート制限実装やAWS WAFの追加が可能です。

### ログ管理

- すべてのリクエストをCloudWatch Logs/OCI Loggingに記録
- Webhook URLは部分的にマスキング
- エラーログの詳細記録

## トラブルシューティング

### Lambda デプロイエラー

```bash
# ZIPファイルのサイズを確認
du -h terraform/aws/slack-webhook-relay.zip

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
docker build -t ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/slack-webhook-relay-repo:latest .
docker push ${OCI_REGION}.ocir.io/${OCI_TENANCY_NAMESPACE}/slack-webhook-relay-repo:latest
```

### Slack送信エラー

```bash
# ログの確認 (AWS)
aws logs tail /aws/lambda/slack-webhook-relay --follow

# ログの確認 (OCI)
oci logging-search search-logs \
  --search-query "search \"<log-group-id>\" | sort by datetime desc"
```

## コスト見積もり

### AWS Lambda (Function URL使用)

- リクエスト: 100万件/月 → 約$0.20
- 実行時間: 30秒、256MB → 約$0.83
- **合計**: 約$1.03/月

**API Gatewayを使わないため、従来の構成より約70%コスト削減!**

### OCI Functions

- リクエスト: 100万件/月 → 約$0.20
- 実行時間: 30秒、256MB → 約$0.60
- API Gateway: 100万リクエスト → 約$3.00
- **合計**: 約$3.80/月

## ライセンス

MIT

## 変更履歴

### v1.1.0

- **AWS版**: API GatewayからLambda Function URLに変更
  - コスト削減: 約70%削減 ($4.53/月 → $1.03/月)
  - シンプルな構成
  - デプロイが高速化
- Lambda Function URLとAPI Gatewayの両形式のクエリパラメータに対応

### v1.0.0

- 初回リリース
- AWS Lambda + API Gateway対応
- OCI Functions対応
- JSON→YAML変換機能

## サポート

Issue報告やプルリクエストを歓迎します。
