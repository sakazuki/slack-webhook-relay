const yaml = require('js-yaml');
const fetch = require('node-fetch');

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
 * Slackのメッセージペイロードを作成
 * @param {string} content - 元のコンテンツ
 * @param {boolean} isJson - JSONかどうか
 * @returns {object} Slackペイロード
 */
function createSlackPayload(content, isJson = false) {
  if (isJson) {
    const yamlContent = convertJsonToYaml(content);
    return {
      text: "Alert Notification",
      blocks: [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*Alert Details*"
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "```\n" + yamlContent + "\n```"
          }
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
    const destinationUrl = event.queryStringParameters?.d || 
                          event.query?.d;

    if (!destinationUrl) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          error: 'Missing required parameter: d (destination webhook URL)'
        })
      };
    }

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
    const slackPayload = createSlackPayload(body, isJson);

    // Slackへ送信
    const result = await sendToSlack(destinationUrl, slackPayload);

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: 'Successfully sent to Slack',
        converted: isJson,
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
  isValidWebhookUrl,
  isJsonString
};
