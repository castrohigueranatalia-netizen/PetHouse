# ============================================================
# PETHOUSE API · Imagen Docker
# Uso: docker build -t pethouse-api . && docker run -p 3001:3001 --env-file .env pethouse-api
# ============================================================
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV NODE_ENV=production
EXPOSE 3001

CMD ["node", "src/server.js"]
