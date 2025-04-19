FROM tomcat:10.1.20-jdk21-temurin

# 기본 webapps 제거 (ROOT, examples 등)
RUN rm -rf /usr/local/tomcat/webapps/*

# WAR 복사
COPY ROOT.war /usr/local/tomcat/webapps/ROOT.war

# 포트 노출
EXPOSE 8080

# Tomcat 실행
CMD ["catalina.sh", "run"]

