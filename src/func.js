const fdk = require('@fnproject/fdk');
const { handler } = require('./handler');

/**
 * OCI Functions エントリーポイント
 */
fdk.handle(async function(input, ctx) {
  try {
    // FDK形式からAPI Gateway形式に変換
    const event = {
      body: typeof input === 'string' ? input : JSON.stringify(input),
      queryStringParameters: ctx._config || {},
      headers: ctx._headers || {},
      isBase64Encoded: false
    };

    // ヘッダーからクエリパラメータを取得（OCI Functionsの場合）
    if (ctx._headers && ctx._headers["Fn-Http-Request-Url"][0]) {
      const url = new URL("https://dummy" + ctx._headers["Fn-Http-Request-Url"][0]);
      event.queryStringParameters = Object.fromEntries(url.searchParams);
    }

    const response = await handler(event);

    return {
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body
    };
  } catch (error) {
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        error: 'Internal server error',
        message: error.message
      })
    };
  }
}, {
  inputMode: 'string',
  outputMode: 'string'
});
