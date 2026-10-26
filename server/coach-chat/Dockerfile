# Dịch vụ coach-chat (spec 2026-10-22 mục 7). Easypanel build từ thư mục này.
FROM node:24-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
USER node
ENV PORT=8080
EXPOSE 8080
CMD ["node", "src/main.mjs"]
