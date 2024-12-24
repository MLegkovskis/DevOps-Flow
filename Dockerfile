# Dockerfile
FROM tomcat:9.0

# Copy the WAR into Tomcat's webapps folder
COPY target/hello-1.0.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080

CMD ["catalina.sh", "run"]
