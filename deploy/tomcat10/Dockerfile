# Java 21 기반 이미지
FROM eclipse-temurin:21-jdk

# 최신 Tomcat 10.1.40 설치
ENV TOMCAT_VERSION=10.1.40

RUN curl -fSL https://dlcdn.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz \
    | tar -xz -C /usr/local && \
    ln -s /usr/local/apache-tomcat-${TOMCAT_VERSION} /usr/local/tomcat

# WAR 파일 복사
COPY ROOT.war /usr/local/tomcat/webapps/ROOT.war

# 업로드 폴더 생성
RUN mkdir -p /blog_demo/uploads

# 기본 포트 노출
EXPOSE 8080

# Tomcat 실행
CMD ["/usr/local/tomcat/bin/catalina.sh", "run"]
