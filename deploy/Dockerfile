# Bundle web build sẵn trên máy dev rồi commit vào nhánh deploy-easypanel
# (xem deploy/publish.sh). Không compile Flutter trong image: VPS chỉ có
# 2 vCPU và đang chạy production cho cms/website.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY web/ /usr/share/nginx/html/
EXPOSE 80
