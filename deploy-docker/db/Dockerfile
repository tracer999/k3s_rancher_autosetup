FROM mariadb:10.6

ENV MYSQL_ROOT_PASSWORD=rootpass
ENV MYSQL_DATABASE=blog_db
ENV MYSQL_USER=bloguser
ENV MYSQL_PASSWORD=blogpass

COPY init.sql /docker-entrypoint-initdb.d/

