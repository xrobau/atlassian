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
    cd /usr/local/fernflower && git checkout f16e194ee46e01ab60098b01f8df9fddb2ffaed3 && \
    ./gradlew build && \
    ./gradlew --stop && \
    cp build/libs/fernflower.jar /usr/local/bin/ && \
    cd / && rm -rf /usr/local/fernflower

# Atlassian pubkey for their SDK repo.
# Annoyingly, the SOURCE URL of
#   https://packages.atlassian.com/api/gpg/key/public
# is mildly corrupt, with random spaces (and other things that
# I stopped caring about). This has been manually fixed by
# using apt-key add (which is more tolerant) to pull it in,
# and then apt-key export B56C9565957495B9 to generate a
# valid .asc file
COPY atlassian-sdk-main.asc /etc/apt/trusted.gpg.d/

COPY *.list /etc/apt/sources.list.d/

# Now add all the things we want in the other packages
# Note that git is installed from backports as bitbucket
# wants something newer than 2.30 (which is currently in
# stable)
RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install patch bbe vim xmlstarlet net-tools atlassian-plugin-sdk && \
    apt-get -t bullseye-backports -y install git && \
    apt-get -y clean

COPY patch.sh /usr/local/bin

RUN echo "bind 'set enable-bracketed-paste off'" >> /etc/bash.bashrc
RUN sed -i 's/mouse=a/mouse=/' /usr/share/vim/*/*.vim
CMD ["/bin/bash"]

