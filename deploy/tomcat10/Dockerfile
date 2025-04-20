FROM eclipse-temurin:21-jdk
ENV TOMCAT_VERSION=10.1.40

# Tomcat 설치
RUN curl -fSL https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    | tar -xz -C /usr/local && \
    ln -s /usr/local/apache-tomcat-${TOMCAT_VERSION} /usr/local/tomcat

# 기존 ROOT 폴더 삭제 (자동 전개 방해 방지)
RUN rm -rf /usr/local/tomcat/webapps/ROOT

# WAR 복사
COPY ROOT.war /usr/local/tomcat/webapps/ROOT.war
RUN ls -lh /usr/local/tomcat/webapps/

# 업로드 경로
RUN mkdir -p /blog_demo/uploads

EXPOSE 8080

CMD ["/bin/bash", "-c", "\
  echo '📦 ROOT.war 파일 상태:' && \
  ls -lh /usr/local/tomcat/webapps/ && \
  echo '🚀 Tomcat 실행 시작...' && \
  /usr/local/tomcat/bin/catalina.sh run"]
