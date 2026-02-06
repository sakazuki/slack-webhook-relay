const { handler } = require('./handler');

/**
 * AWS Lambda エントリーポイント
 * @param {object} event - API Gateway event
 * @param {object} context - Lambda context
 * @returns {Promise<object>} Response
 */
exports.handler = async (event, context) => {
  return await handler(event);
};
