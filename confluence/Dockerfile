FROM atlassian-base:latest

ARG PKG
ARG VERSION
ARG FILE
ARG SRCURL
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000
ARG CONTAINER_USER=${PKG}
ARG CONTAINER_GROUP=${PKG}

ENV PKG_INSTALL=/opt/atlassian/${PKG}
ENV HOMEDIR=/home/${PKG}
ENV MYSQL_DRIVER_VERSION=5.1.44
ENV PKG_HOME=/var/atlassian/${PKG}

COPY response.varfile /usr/local/

RUN wget ${SRCURL} -O /usr/local/${FILE} && \
	chmod +x /usr/local/${FILE} && \
	/usr/local/${FILE} -q -varfile /usr/local/response.varfile && \
	echo confluence.home = ${PKG_HOME} > ${PKG_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties && \
	rm -f /usr/local/${FILE} && \
	/usr/local/bin/patch.sh && \
	rm -f ${PKG_INSTALL}/lib/mysql-connector-java*.jar &&  \
	cp /usr/local/mysql-connector-java*jar ${PKG_INSTALL}/lib/

VOLUME ${PKG_HOME}
WORKDIR ${PKG_HOME}
EXPOSE 8090 8091

COPY docker-entrypoint.sh ${HOMEDIR}/docker-entrypoint.sh
CMD "${HOMEDIR}/docker-entrypoint.sh"



