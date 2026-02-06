FROM node:18-alpine

WORKDIR /function

# package.jsonとpackage-lock.jsonをコピー
COPY src/package*.json ./

# 依存関係をインストール
RUN npm ci --only=production && \
    npm install @fnproject/fdk

# アプリケーションコードをコピー
COPY src/handler.js ./
COPY src/func.js ./

# OCI Functions用のエントリーポイント
CMD ["node", "func.js"]
