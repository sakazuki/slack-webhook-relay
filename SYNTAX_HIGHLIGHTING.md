# Slackでのスニペット風表示例

## 実装方法の変更

Slack Incoming Webhookでは真のファイルスニペットをアップロードできないため、**Attachmentとフォーマット済みテキスト**を使用して、スニペットに近い見た目を実現しています。

## Before (通常のJSON送信)

通常、Slackに生のJSONを送ると以下のように表示されます:

```
{"alert":"High CPU Usage","severity":"critical","host":"web-server-01","cpu_usage":95.3,"memory_usage":87.2,"details":{"process":"java","pid":1234,"threshold":80},"timestamp":"2025-02-07T10:30:00Z"}
```

- 読みにくい
- キーと値の区別がつきにくい
- 階層構造が分かりにくい
- 長いと横スクロールが必要

## After (このAPI経由でスニペット風表示)

このAPIを経由すると、Slackで以下のように表示されます:

```
┌─────────────────────────────────────┐
│ 🚨 Alert Notification                │
│ ┌─────────────────────────────────┐ │
│ │ 📋 Alert Details                 │ │ ← ヘッダー
│ │                                  │ │
│ │ *alert:* High CPU Usage         │ │ ← キーが太字
│ │ *severity:* critical            │ │ ← 値は通常テキスト
│ │ *host:* web-server-01           │ │
│ │ *cpu_usage:* 95.3               │ │
│ │ *memory_usage:* 87.2            │ │
│ │ *details:*                      │ │ ← ネストの親
│ │   *process:* java               │ │ ← インデントで階層
│ │   *pid:* 1234                   │ │
│ │   *threshold:* 80               │ │
│ │ *timestamp:* '2025-02-07...'    │ │
│ │ ─────────────────────────────   │ │ ← 区切り線
│ │ 📄 Format: YAML | ⏰ 2025-02-07 │ │ ← フッター
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
     └── 色付きサイドバー（赤系）
```

### フォーマットの特徴

1. **色付きサイドバー**: 左側に赤い縦線で注意を引く
2. **太字のキー名**: `*key:*` で強調表示
3. **階層表示**: インデントで構造が明確
4. **ヘッダーとフッター**: 絵文字で視認性向上
5. **タイムスタンプ**: アラート受信時刻を記録

## 技術的な実装

### フォーマット変換ロジック

```javascript
function formatYamlForSlack(yamlContent) {
  // キー: 値 のパターンを *キー:* 値 に変換
  // - キー名を太字にして視認性を向上
  // - 階層構造（インデント）は保持
}
```

## 複雑なアラートの例

### JSON (変換前)

```json
{"alert_name":"Database Connection Pool Exhausted","severity":"critical","environment":"production","service":"api-backend","region":"ap-northeast-1","metrics":{"active_connections":100,"max_connections":100,"queue_size":50,"avg_wait_time_ms":5000,"error_rate":0.23},"impact":{"affected_users":1500,"transaction_failures":234},"tags":["database","performance","api","urgent"],"runbook_url":"https://wiki.example.com/runbooks/db-pool-exhausted","notified":["oncall-team","platform-team"]}
```

### スニペット風YAML表示 (変換後)

Slackでの実際の表示:

```
🚨 Alert Notification
┌────────────────────────────────────────┐
│ 📋 Alert Details                        │
│                                         │
│ *alert_name:* Database Connection...   │
│ *severity:* critical                    │
│ *environment:* production               │
│ *service:* api-backend                  │
│ *region:* ap-northeast-1                │
│ *metrics:*                              │
│   *active_connections:* 100             │
│   *max_connections:* 100                │
│   *queue_size:* 50                      │
│   *avg_wait_time_ms:* 5000              │
│   *error_rate:* 0.23                    │
│ *impact:*                               │
│   *affected_users:* 1500                │
│   *transaction_failures:* 234           │
│ *tags:*                                 │
│   - `database`                          │
│   - `performance`                       │
│   - `api`                               │
│   - `urgent`                            │
│ *runbook_url:* https://wiki.example...  │
│ *notified:*                             │
│   - `oncall-team`                       │
│   - `platform-team`                     │
│ ────────────────────────────────────    │
│ 📄 Format: YAML | ⏰ 2025-02-07T10:30   │
└────────────────────────────────────────┘
```

階層構造とメトリクスが一目で理解できます!

## Slackでの視覚的な改善点

### 1. 色付きサイドバー
- 赤系 (`#ff6b6b`) で緊急性を表現
- メッセージ全体を視覚的に区別

### 2. フォーマット
- **太字のキー**: 重要な情報が目立つ
- **インデント**: 階層が明確
- **リスト項目**: バッククォートで囲んで識別しやすく

### 3. アイコンと絵文字
- 🚨 アラート通知
- 📋 詳細情報
- 📄 フォーマット種類
- ⏰ タイムスタンプ

## 従来の方式との比較

| 方式 | 実装 | 色分け | 階層表示 | Webhook対応 |
|------|------|--------|----------|-------------|
| コードブロック | ```yaml``` | ❌* | ✅ | ✅ |
| File Snippet | files.upload API | ✅ | ✅ | ❌ |
| **Attachment** | **attachments + blocks** | **✅** | **✅** | **✅** |

*コードブロックでの`yaml`指定はWebhook経由では色分けされない場合が多い

## まとめ

| 項目 | JSON | スニペット風YAML |
|------|------|------------------|
| 可読性 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 階層の明確さ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| 視覚的な強調 | ❌ | ✅ (太字キー) |
| 色付きサイドバー | ❌ | ✅ (赤系) |
| 視覚的な疲労 | 高い | 低い |
| オンコール対応 | 遅い | 速い |
| Webhook対応 | ✅ | ✅ |

Attachmentベースのスニペット風表示により、Incoming Webhook経由でも視認性の高いアラート通知が実現できます。

**真のファイルスニペット**が必要な場合は、Slack Web APIの`chat.postMessage` + `files.upload`を使う方法もありますが、その場合はOAuthトークンが必要になります。
