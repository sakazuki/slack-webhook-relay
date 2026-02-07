const fdk = require("@fnproject/fdk");
const { handler } = require("./handler");

/**
 * OCI Functions entry point
 */
fdk.handle(
  async function (input, ctx) {
    try {
      // Convert from FDK format to API Gateway format
      const event = {
        body: typeof input === "string" ? input : JSON.stringify(input),
        queryStringParameters: ctx._config || {},
        headers: ctx._headers || {},
        isBase64Encoded: false,
      };

      // Get query parameters from headers (for OCI Functions)
      if (ctx._headers && ctx._headers["Fn-Http-Request-Url"][0]) {
        const url = new URL(
          "https://dummy" + ctx._headers["Fn-Http-Request-Url"][0],
        );
        event.queryStringParameters = Object.fromEntries(url.searchParams);
      }

      const response = await handler(event);

      return {
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
      };
    } catch (error) {
      return {
        statusCode: 500,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          error: "Internal server error",
          message: error.message,
        }),
      };
    }
  },
  {
    inputMode: "string",
    outputMode: "string",
  },
);
