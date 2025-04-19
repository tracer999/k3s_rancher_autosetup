# Base image
FROM tomcat:10.1-jdk17-temurin

# 빌드 결과물 복사
COPY ROOT.war /usr/local/tomcat/webapps/ROOT.war

# 업로드 폴더 생성
RUN mkdir -p /blog_demo/uploads
