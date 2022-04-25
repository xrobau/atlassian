FROM atlassian-base:latest
MAINTAINER Rob Thomas <xrobau@gmail.com>

ARG JIRA_VERSION
ARG JIRA_FILE
ARG JIRA_URL
ARG CONTAINER_UID=1000
ARG CONTAINER_USER=jira
ARG CONTAINER_GID=1000
ARG CONTAINER_GROUP=jira
ARG LANG_LANGUAGE=en
ARG LANG_COUNTRY=US
ARG BUILD_DATE=undefined

ENV JIRA_USER=jira                            \
    JIRA_GROUP=jira                           \
    JIRA_CONTEXT_PATH=ROOT                    \
    JIRA_HOME=/var/atlassian/jira             \
    JIRA_INSTALL=/opt/atlassian/jira          \
    JIRA_SCRIPTS=/usr/local/share/atlassian   \
    MYSQL_DRIVER_VERSION=5.1.46               \
    DOCKERIZE_VERSION=v0.6.1

ENV LANG=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8

COPY imagescripts ${JIRA_SCRIPTS}

# Install Jira
RUN wget -O /tmp/jira.bin ${JIRA_URL} && \
    chmod +x /tmp/jira.bin && \
    /tmp/jira.bin -q -varfile ${JIRA_SCRIPTS}/response.varfile && \
    rm -f /tmp/jira.bin && \
    /usr/local/bin/patch.sh && \
    chown -R 1000.1000 /opt/atlassian/jira && \
    # Install MySQL database driver \
    rm -f ${JIRA_INSTALL}/lib/mysql-connector-java*.jar && \
    cp /usr/local/mysql-connector-java*jar ${JIRA_INSTALL}/lib/

USER jira
WORKDIR ${JIRA_HOME}
VOLUME ["/var/atlassian/jira"]
EXPOSE 8080
COPY launch.sh common.sh /usr/local/share/atlassian/
COPY docker-entrypoint.sh /usr/local/bin
CMD ["/usr/local/bin/docker-entrypoint.sh", "jira"]

