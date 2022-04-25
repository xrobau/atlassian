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
ENV PKG_HOME=/var/atlassian/${PKG}
ENV HOMEDIR=/home/${PKG}
ENV MYSQL_DRIVER_VERSION=5.1.44

RUN addgroup --gid ${CONTAINER_GID} ${CONTAINER_GROUP}
RUN adduser --system --uid ${CONTAINER_UID} --ingroup ${CONTAINER_GROUP} --home ${HOMEDIR} --shell /bin/bash ${CONTAINER_USER}

COPY response.varfile /usr/local/

RUN wget ${SRCURL} -O /usr/local/${FILE} && \
	chmod +x /usr/local/${FILE} && \
	mkdir -p ${PKG_INSTALL} ${PKG_HOME} && chown ${CONTAINER_UID}.${CONTAINER_GID} ${PKG_INSTALL} ${PKG_HOME} && \
	su ${PKG} /bin/bash -c "/usr/local/${FILE} -q -varfile /usr/local/response.varfile" && \
	rm -f /usr/local/${FILE} && \
	/usr/local/bin/patch.sh && \
	rm -f ${PKG_INSTALL}/lib/mysql-connector-java*.jar &&  \
	cp /usr/local/mysql-connector-java*jar ${PKG_INSTALL}/lib/

EXPOSE 7990

VOLUME /var/atlassian/${PKG}
WORKDIR /var/atlassian/${PKG}
COPY docker-entrypoint.sh ${HOMEDIR}/docker-entrypoint.sh
USER ${PKG}
CMD ${HOMEDIR}/docker-entrypoint.sh



