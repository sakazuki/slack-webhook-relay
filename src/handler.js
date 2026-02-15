const yaml = require("js-yaml");

/**
 * Convert JSON string to YAML
 * @param {string} jsonString - JSON string
 * @returns {string} YAML string
 */
function convertJsonToYaml(jsonString) {
  try {
    const jsonObj = JSON.parse(jsonString);
    return yaml.dump(jsonObj, {
      indent: 2,
      lineWidth: 120,
      noRefs: true,
    });
  } catch (error) {
    throw new Error(`JSON parse error: ${error.message}`);
  }
}

/**
 * Format YAML for better readability (for Slack)
 * @param {string} yamlContent - YAML string
 * @returns {string} Formatted YAML
 */
function formatYamlForSlack(yamlContent) {
  const lines = yamlContent.split("\n");
  let inHeredoc = false; // Flag to track if we're inside heredoc
  let heredocIndent = 0; // Base indentation for heredoc

  const formatted = lines.map((line, index) => {
    // Return empty lines as-is
    if (line.trim() === "") {
      return line;
    }

    const currentIndent = line.match(/^(\s*)/)[1].length;

    // Process heredoc content
    if (inHeredoc) {
      // Lines inside heredoc have deeper indentation than base
      if (currentIndent > heredocIndent) {
        // Return heredoc lines as-is (no highlighting)
        return line;
      } else {
        // Indentation decreased = end of heredoc
        inHeredoc = false;
        heredocIndent = 0;
        // Process this line as normal
      }
    }

    // Detect start of heredoc
    // Lines starting with |, |-, |+, >, >-, >+ are heredoc starts
    if (line.match(/^\s*[\w'_-]+:\s*[|>][-+]?\s*$/)) {
      inHeredoc = true;
      heredocIndent = currentIndent;
      // Make only the key part bold
      return line.replace(/^(\s*)([\w'_-]+)(:\s*[|>][-+]?\s*)$/, "$1*$2*$3");
    }

    // Match key: value pattern
    const keyValueMatch = line.match(/^(\s*)([\w'_-]+):\s*(.*)$/);
    if (keyValueMatch) {
      const indent = keyValueMatch[1];
      const key = keyValueMatch[2];
      const value = keyValueMatch[3];

      // Highlight value in bold if present
      if (value && value !== "" && value !== "null") {
        return `${indent}*${key}:* ${value}`;
      } else {
        // For parent keys with no value, only make key bold
        return `${indent}*${key}:*`;
      }
    }

    // List items
    if (line.match(/^\s*-\s+/)) {
      return line.replace(/^(\s*-\s+)(.+)$/, "$1`$2`");
    }

    return line;
  });

  return formatted.join("\n");
}

/**
 * Create Slack message payload
 * @param {string} content - Original content
 * @param {boolean} isJson - Whether content is JSON
 * @param {string} mode - Display mode: 'simple' (code block only), 'block' (blocks without attachment), 'attachments' (with color sidebar)
 * @returns {object} Slack payload
 */
function createSlackPayload(content, isJson = false, mode = "block") {
  if (isJson) {
    const yamlContent = convertJsonToYaml(content);

    // Simple mode: code block only
    if (mode === "simple") {
      return {
        text: "Alert Notification",
        blocks: [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "```\n" + yamlContent + "```",
            },
          },
        ],
      };
    }

    const formattedYaml = formatYamlForSlack(yamlContent);
    const blocks = [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "📋 Alert Details",
          emoji: true,
        },
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: formattedYaml,
        },
      },
      {
        type: "divider",
      },
      {
        type: "context",
        elements: [
          {
            type: "mrkdwn",
            text: `📄 Format: YAML | ⏰ ${new Date().toISOString()}`,
          },
        ],
      },
    ];

    // Block mode: blocks without attachment (no color sidebar)
    if (mode === "block") {
      return {
        text: "🚨 Alert Notification",
        blocks: blocks,
      };
    }

    // Attachments mode: snippet-style display with color sidebar
    return {
      text: "🚨 Alert Notification",
      attachments: [
        {
          color: "#ff6b6b",
          blocks: blocks,
        },
      ],
    };
  } else {
    // For plain text
    return {
      text: content,
    };
  }
}

/**
 * Send message to Slack Webhook
 * @param {string} webhookUrl - Webhook URL
 * @param {object} payload - Payload to send
 * @returns {Promise<object>} Response
 */
async function sendToSlack(webhookUrl, payload) {
  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Slack API error: ${response.status} - ${errorText}`);
  }

  return {
    statusCode: response.status,
    body: await response.text(),
  };
}

/**
 * Validate Webhook URL
 * @param {string} url - URL to validate
 * @returns {boolean}
 */
function isValidWebhookUrl(url) {
  try {
    const parsedUrl = new URL(url);
    // Verify it's a Slack webhook URL
    return (
      parsedUrl.hostname.includes("slack.com") ||
      parsedUrl.hostname.includes("hooks.slack.com")
    );
  } catch {
    return false;
  }
}

/**
 * Determine if request body is JSON
 * @param {string} body - Request body
 * @returns {boolean}
 */
function isJsonString(body) {
  if (!body || typeof body !== "string") {
    return false;
  }

  const trimmed = body.trim();
  if (
    (trimmed.startsWith("{") && trimmed.endsWith("}")) ||
    (trimmed.startsWith("[") && trimmed.endsWith("]"))
  ) {
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
 * Main handler
 * @param {object} event - Event object
 * @returns {Promise<object>} Response
 */
async function handler(event) {
  try {
    // Get destination webhook URL from query parameters
    // Support both Lambda Function URL and API Gateway
    const destinationUrl =
      event.queryStringParameters?.d ||
      event.query?.d ||
      (event.rawQueryString &&
        new URLSearchParams(event.rawQueryString).get("d"));

    if (!destinationUrl) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Missing required parameter: d (destination webhook URL)",
        }),
      };
    }

    // Get mode parameter (simple, block, attachments)
    // Default is 'block'
    const mode =
      event.queryStringParameters?.mode ||
      event.query?.mode ||
      (event.rawQueryString &&
        new URLSearchParams(event.rawQueryString).get("mode")) ||
      "block";

    // Validate webhook URL
    if (!isValidWebhookUrl(destinationUrl)) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Invalid Slack webhook URL",
        }),
      };
    }

    // Get request body
    let body = event.body;

    // Handle Base64 encoding from API Gateway
    if (event.isBase64Encoded && body) {
      body = Buffer.from(body, "base64").toString("utf-8");
    }

    if (!body) {
      return {
        statusCode: 400,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Missing request body",
        }),
      };
    }

    // Determine if content is JSON
    const isJson = isJsonString(body);

    // Create Slack payload
    const slackPayload = createSlackPayload(body, isJson, mode);

    // Send to Slack
    const result = await sendToSlack(destinationUrl, slackPayload);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: "Successfully sent to Slack",
        converted: isJson,
        mode: mode,
        destination: destinationUrl.split("/").slice(0, 3).join("/") + "/***",
      }),
    };
  } catch (error) {
    console.error("Error:", error);
    return {
      statusCode: 500,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        error: "Internal server error",
        message: error.message,
      }),
    };
  }
}

module.exports = {
  handler,
  convertJsonToYaml,
  createSlackPayload,
  formatYamlForSlack,
  isValidWebhookUrl,
  isJsonString,
};
