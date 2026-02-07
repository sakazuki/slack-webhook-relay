const yaml = require('js-yaml');

/**
 * JSON文字列をYAMLに変換
 * @param {string} jsonString - JSON文字列
 * @returns {string} YAML文字列
 */
function convertJsonToYaml(jsonString) {
  try {
    const jsonObj = JSON.parse(jsonString);
    return yaml.dump(jsonObj, {
      indent: 2,
      lineWidth: 120,
      noRefs: true
    });
  } catch (error) {
    throw new Error(`JSON parse error: ${error.message}`);
  }
}

/**
 * YAMLを見やすくフォーマット（Slack用）
 * @param {string} yamlContent - YAML文字列
 * @returns {string} フォーマット済みYAML
 */
function formatYamlForSlack(yamlContent) {
  const lines = yamlContent.split('\n');
  let inHeredoc = false; // ヒアドキュメント内かどうかのフラグ
  let heredocIndent = 0; // ヒアドキュメントの基準インデント

  const formatted = lines.map((line, index) => {
    // 空行はそのまま
    if (line.trim() === '') {
      return line;
    }

    const currentIndent = line.match(/^(\s*)/)[1].length;

    // ヒアドキュメント内の処理
    if (inHeredoc) {
      // ヒアドキュメント内の行は、基準インデントより深いインデントを持つ
      if (currentIndent > heredocIndent) {
        // ヒアドキュメント内の行はそのまま返す（ハイライトしない）
        return line;
      } else {
        // インデントが戻った = ヒアドキュメント終了
        inHeredoc = false;
        heredocIndent = 0;
        // この行は通常の処理へ進む
      }
    }

    // ヒアドキュメントの開始を検出
    // |, |-, |+, >, >-, >+ などで始まる行はヒアドキュメントの開始
    if (line.match(/^\s*[\w'_-]+:\s*[|>][-+]?\s*$/)) {
      inHeredoc = true;
      heredocIndent = currentIndent;
      // キー部分だけを太字にする
      return line.replace(/^(\s*)([\w'_-]+)(:\s*[|>][-+]?\s*)$/, '$1*$2*$3');
    }

    // キー: 値 のパターンにマッチ
    const keyValueMatch = line.match(/^(\s*)([\w'_-]+):\s*(.*)$/);
    if (keyValueMatch) {
      const indent = keyValueMatch[1];
      const key = keyValueMatch[2];
      const value = keyValueMatch[3];

      // 値がある場合は太字で強調
      if (value && value !== '' && value !== 'null') {
        return `${indent}*${key}:* ${value}`;
      } else {
        // 値がない場合（ネストの親）は太字のキーのみ
        return `${indent}*${key}:*`;
      }
    }

    // リスト項目
    if (line.match(/^\s*-\s+/)) {
      return line.replace(/^(\s*-\s+)(.+)$/, '$1`$2`');
    }

    return line;
  });

  return formatted.join('\n');
}

/**
 * Slackのメッセージペイロードを作成
 * @param {string} content - 元のコンテンツ
 * @param {boolean} isJson - JSONかどうか
 * @param {boolean} simple - シンプルモード（シンタックスハイライトなし）
 * @returns {object} Slackペイロード
 */
function createSlackPayload(content, isJson = false, simple = false) {
  if (isJson) {
    const yamlContent = convertJsonToYaml(content);
    // シンプルモード: コードブロックのみ
    if (simple) {
      return {
        text: "Alert Notification",
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "```\n" + yamlContent + "```"
            }
          }
        ]
      };
    }
    // 通常モード: スニペット風表示
    const formattedYaml = formatYamlForSlack(yamlContent);
    // Attachmentでスニペット風に表示（色付きサイドバー + フォーマット）
    return {
      text: "🚨 Alert Notification",
      attachments: [
        {
          color: "#ff6b6b",
          blocks: [
            {
              type: "header",
              text: {
                type: "plain_text",
                text: "📋 Alert Details",
                emoji: true
              }
            },
            {
              type: "section",
              text: {
                type: "mrkdwn",
                text: formattedYaml
              }
            },
            {
              type: "divider"
            },
            {
              type: "context",
              elements: [
                {
                  type: "mrkdwn",
                  text: `📄 Format: YAML | ⏰ ${new Date().toISOString()}`
                }
              ]
            }
          ]
        }
      ]
    };
  } else {
    // プレーンテキストの場合
    return {
      text: content
    };
  }
}

/**
 * Slack Webhookへメッセージ送信
 * @param {string} webhookUrl - Webhook URL
 * @param {object} payload - 送信ペイロード
 * @returns {Promise<object>} レスポンス
 */
async function sendToSlack(webhookUrl, payload) {
  const response = await fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(payload)
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Slack API error: ${response.status} - ${errorText}`);
  }

  return {
    statusCode: response.status,
    body: await response.text()
  };
}

/**
 * WebhookURLのバリデーション
 * @param {string} url - 検証するURL
 * @returns {boolean}
 */
function isValidWebhookUrl(url) {
  try {
    const parsedUrl = new URL(url);
    // Slackのwebhook URLであることを確認
    return parsedUrl.hostname.includes('slack.com') || 
           parsedUrl.hostname.includes('hooks.slack.com');
  } catch {
    return false;
  }
}

/**
 * リクエストボディがJSONかどうかを判定
 * @param {string} body - リクエストボディ
 * @returns {boolean}
 */
function isJsonString(body) {
  if (!body || typeof body !== 'string') {
    return false;
  }
  
  const trimmed = body.trim();
  if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
    try {
      JSON.parse(trimmed);
      return true;
    } catch {
      return false;
    }
  }
  return false;
}

/**
 * メインハンドラー
 * @param {object} event - イベントオブジェクト
 * @returns {Promise<object>} レスポンス
 */
async function handler(event) {
  try {
    // クエリパラメータから宛先Webhook URLを取得
    // Lambda Function URL と API Gateway の両方に対応
    const destinationUrl = event.queryStringParameters?.d || 
                          event.query?.d ||
                          (event.rawQueryString && new URLSearchParams(event.rawQueryString).get('d'));

    if (!destinationUrl) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'Missing required parameter: d (destination webhook URL)'
        })
      };
    }

    // シンプルモードフラグを取得
    const simpleMode = event.queryStringParameters?.simple === 'true' || 
                       event.query?.simple === 'true' ||
                       (event.rawQueryString && new URLSearchParams(event.rawQueryString).get('simple') === 'true');

    // Webhook URLのバリデーション
    if (!isValidWebhookUrl(destinationUrl)) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'Invalid Slack webhook URL'
        })
      };
    }

    // リクエストボディを取得
    let body = event.body;
    
    // API GatewayのBase64エンコード対応
    if (event.isBase64Encoded && body) {
      body = Buffer.from(body, 'base64').toString('utf-8');
    }

    if (!body) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'Missing request body'
        })
      };
    }

    // JSONかどうかを判定
    const isJson = isJsonString(body);

    // Slackペイロードを作成
    const slackPayload = createSlackPayload(body, isJson, simpleMode);

    // Slackへ送信
    const result = await sendToSlack(destinationUrl, slackPayload);

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Successfully sent to Slack',
        converted: isJson,
        simple: simpleMode,
        destination: destinationUrl.split('/').slice(0, 3).join('/') + '/***'
      })
    };

  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message
      })
    };
  }
}

module.exports = {
  handler,
  convertJsonToYaml,
  createSlackPayload,
  formatYamlForSlack,
  isValidWebhookUrl,
  isJsonString
};
