FROM nginx:1.17.7-alpine
COPY letsencrypt/ /etc/letsencrypt/ 
COPY le.sksh.nginx.conf /etc/nginx/conf.d/default.conf
COPY src/public /var/www/html
