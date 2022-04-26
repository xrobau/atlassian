FROM openjdk:11-jdk-bullseye
LABEL org.opencontainers.image.authors="Rob Thomas <xrobau@gmail.com>"

ARG LANG_LANGUAGE=en
ARG LANG_COUNTRY=US
ENV LANG=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8
ENV MYSQL_DRIVER_VERSION=5.1.44

# Import mysql driver used by everything
RUN curl -L http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz | \
	tar --directory=/usr/local --strip-components=1 -zxv \
	mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar

# Build fernflower
RUN git clone https://github.com/fesh0r/fernflower /usr/local/fernflower && \
    cd /usr/local/fernflower && \
    ./gradlew build && \
    ./gradlew --stop && \
    cp build/libs/fernflower.jar /usr/local/bin/ && \
    cd / && rm -rf /usr/local/fernflower

# Now add all the things we want in the other packages
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install patch bbe vim xmlstarlet net-tools && \
    apt-get -y clean

COPY patch.sh /usr/local/bin

RUN echo "bind 'set enable-bracketed-paste off'" >> /etc/bash.bashrc
RUN sed -i 's/mouse=a/mouse=/' /usr/share/vim/*/*.vim
CMD ["/bin/bash"]

