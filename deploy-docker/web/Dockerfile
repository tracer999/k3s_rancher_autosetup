FROM nginx:alpine

# 기본 conf 제거
RUN rm /etc/nginx/conf.d/default.conf

# 새 conf 복사
COPY nginx.conf /etc/nginx/nginx.conf

