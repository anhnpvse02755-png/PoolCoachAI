# Dịch vụ notify (spec P6b §3). Easypanel build từ nhánh deploy-notify, nơi publish-notify.sh đặt sẵn bin/ và lib/ của helper.
# Helper là bundle của `dart build cli`: bin/notify_plan cần thư mục lib/ cạnh nó (thư viện native, có thể rỗng).
FROM node:24-bookworm-slim
WORKDIR /app
ENV TZ=UTC NODE_ENV=production PORT=8080 NOTIFY_PLAN_BIN=/app/bin/notify_plan
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY bin ./bin
COPY lib ./lib
RUN chmod +x ./bin/notify_plan && [ "$(uname -m)" = "x86_64" ] && ./bin/notify_plan --self-test >/dev/null
USER node
EXPOSE 8080
CMD ["node", "src/main.mjs"]
