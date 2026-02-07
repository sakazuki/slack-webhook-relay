# Changelog

## v1.4.0

- **Simple Mode Added**: Send plain YAML without formatting using `simple=true` parameter
- **Improved Key Extraction**: Support for key names containing single quotes (e.g., `user's_data`)
  - Regex changed from `[\w_-]` to `[\w'_-]`
- **OCI Terraform Improvements**:
  - Fixed API Gateway Logs resource reference (gateway → deployment)
  - Updated OCI Provider version to 8.0 or higher
  - Added policies and dynamic groups for API Gateway to execute Functions
  - Use compartment name in policy statements (`compartment id` → `compartment`)

## v1.3.0

- **Node.js Version Update**:
  - OCI Functions: Updated to Node.js 25
  - AWS Lambda: Updated to Node.js 20
- **Dependencies Optimization**:
  - Removed `node-fetch`, using Node.js standard `fetch`
  - Only `js-yaml` as dependency for lighter footprint
- **formatYamlForSlack Improvements**:
  - Proper handling of `'null'` string values
  - Disable highlighting inside here-documents (prevent false detection of URLs, timestamps, etc.)
  - Accurate here-document detection based on indentation
- **Build Improvements**: Removed node_modules exclusion from Terraform (include dependencies in deployment)

## v1.2.0

- **Snippet-style Display Support**: Achieved snippet-style display using Slack Attachments
  - Color-coded sidebar (red tone) for emphasis
  - Bold key names for better distinction
  - Enhanced visibility with headers, footers, and emojis
  - Works with Incoming Webhook (no OAuth token required)
- Keys and values are now visually distinct, further improving readability

## v1.1.0

- **AWS Edition**: Changed from API Gateway to Lambda Function URL
  - Cost reduction: ~70% savings ($4.53/month → $1.03/month)
  - Simplified architecture
  - Faster deployment
- Query parameter support for both Lambda Function URL and API Gateway formats

## v1.0.0

- Initial release
- AWS Lambda + API Gateway support
- OCI Functions support
- JSON → YAML conversion feature
