FROM debian:bookworm

RUN apt-get update && apt-get install -y nginx openssl
RUN mkdir -p /etc/nginx/ssl
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=JP/ST=Tokyo/L=Inception/O=42/OU=42/CN=mrio.42.fr/UID=mrio"

COPY conf/nginx.conf /etc/nginx/nginx.conf


RUN mkdir -p /var/run/nginx
RUN chmod +x /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
