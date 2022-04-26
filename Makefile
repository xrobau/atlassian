PROJECT=atlassian

JIRA_VERSION=8.22.2
JIRA_FILE=atlassian-jira-software-$(JIRA_VERSION)-x64.bin
JIRA_URL=https://product-downloads.atlassian.com/software/jira/downloads/$(JIRA_FILE)
JIRA_ARGS=--build-arg JIRA_VERSION=$(JIRA_VERSION) --build-arg JIRA_FILE=$(JIRA_FILE) --build-arg JIRA_URL=$(JIRA_URL)

CROWD_VERSION=4.4.1
CROWD_FILE=atlassian-crowd-$(CROWD_VERSION).tar.gz
CROWD_SRCURL=https://product-downloads.atlassian.com/software/crowd/downloads/$(CROWD_FILE)
CROWD_ARGS=--build-arg CROWD_VERSION=$(CROWD_VERSION) --build-arg CROWD_FILE=$(CROWD_FILE) --build-arg CROWD_SRCURL=$(CROWD_SRCURL)

CONF_VERSION=7.17.1
CONF_FILE=atlassian-confluence-$(CONF_VERSION)-x64.bin
CONF_SRCURL=https://product-downloads.atlassian.com/software/confluence/downloads/$(CONF_FILE)
CONF_ARGS=--build-arg VERSION=$(CONF_VERSION) --build-arg FILE=$(CONF_FILE) --build-arg SRCURL=$(CONF_SRCURL) --build-arg PKG=confluence

BB_VERSION=7.21.0
BB_FILE=atlassian-bitbucket-$(BB_VERSION)-x64.bin
BB_SRCURL=https://product-downloads.atlassian.com/software/stash/downloads/$(BB_FILE)
BB_ARGS=--build-arg VERSION=$(BB_VERSION) --build-arg FILE=$(BB_FILE) --build-arg SRCURL=$(BB_SRCURL) --build-arg PKG=bitbucket

VOLUMES=-v $(shell pwd)/debug:/usr/local/debug

COMPOSERVERSION=1.29.2
DOCKERFILE=docker-compose.yml

# Default container to tail or enter when 'make start' or 'make shell' is run
DEFAULT=crowd

# Simply to identify the build if multiple people are
# working on it. If you're not me, you can ignore this.
USERNAME=atlassian

.PHONY: help
help: | setup
	@echo "This builds the entire Atlassian Ecosystem as docker containers."
	@echo "If you're xrobau, you can also use 'make push' to send it to dockerhub."
	@echo "Also run 'make psql' to launch psql and 'make creates' to generate the"
	@echo "sql create database commands (Generates a random password on first use)"

.PHONY: setup
setup: /usr/bin/docker-compose-$(COMPOSERVERSION) /usr/bin/uuid /usr/local/bin/dive

.PHONY: start
start: | setup
	@/usr/bin/docker-compose -f $(DOCKERFILE) -p $(PROJECT) up --detach
	docker logs --tail 100 -f $(PROJECT)_$(DEFAULT)_1

.PHONY: psql
psql: | setup
	@/usr/bin/docker-compose -f $(DOCKERFILE) -p $(PROJECT) up --detach db || :
	@docker exec -it ${PROJECT}_db_1 /usr/bin/psql

.PHONY: stop
stop: | setup
	@/usr/bin/docker-compose -f $(DOCKERFILE) -p $(PROJECT) down || :

.PHONY: shell
shell: | setup
	@docker exec -it $(PROJECT)_$(DEFAULT)_1 bash


.PHONY: build
build: jira crowd confluence bitbucket | setup

.docker_base_build: $(wildcard base/*)
	@docker build --tag atlassian-base:latest base/
	@touch $@

base-shell: .docker_base_build
	@docker run --rm -it atlassian-base:latest /bin/bash

.PHONY: jira
jira: .docker_jira_build_$(JIRA_VERSION)

.docker_jira_build_$(JIRA_VERSION): .docker_base_build $(wildcard jira/*)
	@docker build $(JIRA_ARGS) --tag jira:$(JIRA_VERSION) jira/
	@touch $@

.PHONY: crowd
crowd: .docker_crowd_build_$(CROWD_VERSION)
.docker_crowd_build_$(CROWD_VERSION): .docker_base_build $(wildcard crowd/*)
	@docker build $(CROWD_ARGS) --tag crowd:$(CROWD_VERSION) crowd/
	@touch $@

.PHONY: confluence
confluence: .docker_conf_build_$(CONF_VERSION)
.docker_conf_build_$(CONF_VERSION): .docker_base_build $(wildcard confluence/*)
	@docker build $(CONF_ARGS) --tag confluence:$(CONF_VERSION) confluence/
	@touch $@

.PHONY: bitbucket
bitbucket: .docker_bb_build_$(BB_VERSION)
.docker_bb_build_$(BB_VERSION): .docker_base_build $(wildcard bitbucket/*)
	@docker build $(BB_ARGS) --tag bitbucket:$(BB_VERSION) bitbucket/
	@touch $@


creates: .create_crowd .create_jira .create_confluence .create_bitbucket
	@cat .create_crowd
	@cat .create_jira
	@cat .create_confluence
	@cat .create_bitbucket

genpass = $(shell echo $$(cat .uuid).$(1) | md5sum | cut -c1-16)

define genbase
	@echo "# Create for $(1) generated at $(shell date)" > .create_$(1)
	@echo "CREATE USER $(1)user WITH PASSWORD '$(call genpass,$(1))';" >> .create_$(1)
	@echo "CREATE DATABASE $(1)db WITH ENCODING 'utf8' LC_COLLATE 'en_US.utf8' LC_CTYPE 'en_US.utf8' TEMPLATE template0;" >> .create_$(1)
	@echo "GRANT ALL PRIVILEGES ON DATABASE $(1)db TO $(1)user;" >> .create_$(1)
	@echo "" >> .create_$(1)
endef

.create_%: .uuid
	@echo "Generating create for $* (This will only happen once)"
	$(call genbase,$*)

.uuid:
	/usr/bin/uuid > $@

.PHONY: getrv
getrv: .lastbuild .buildnumber
	$(eval RELEASE=$(USERNAME)-$(shell cat .lastbuild)-$(shell cat .buildnumber))

.PHONY: show-releasevar
show-releasevar: getrv
	@echo "Build tag is '$(RELEASE)' - use 'make increment-releasevar' to bump"

increment-releasevar: .lastbuild .buildnumber
	@[ "$$(cat .lastbuild)" != "$$(date --utc +'%Y%m%d')" ] && date --utc +'%Y%m%d' > .lastbuild && echo 0 > .buildnumber || :
	@echo $$(( $$(cat .buildnumber) + 1 )) > .buildnumber

.lastbuild:
	@date --utc +'%Y%m%d' > .lastbuild

.buildnumber:
	@echo 1 > .buildnumber

prod: increment-releasevar push

.PHONY: push
push: .push_base .push_bb .push_conf .push_jira .push_crowd

.tag_base: .lastbuild .buildnumber .docker_base_build
	$(eval RELEASE=$(USERNAME)-$(shell cat .lastbuild)-$(shell cat .buildnumber))
	@echo Tagging xrobau/atlassian-base:$(RELEASE)
	@docker tag atlassian-base:latest xrobau/atlassian-base:$(RELEASE)
	@touch $@

.push_base: .tag_base
	$(eval RELEASE=$(USERNAME)-$(shell cat .lastbuild)-$(shell cat .buildnumber))
	docker push xrobau/atlassian-base:$(RELEASE)
	touch $@

.tag_bb_$(BB_VERSION): .docker_bb_build_$(BB_VERSION)
	@echo Tagging xrobau/patched-bitbucket:$(BB_VERSION)
	@docker tag bitbucket:$(BB_VERSION) xrobau/patched-bitbucket:$(BB_VERSION)
	@touch $@

.push_bb: .tag_bb_$(BB_VERSION)
	@docker push xrobau/patched-bitbucket:$(BB_VERSION)
	@touch $@

.tag_conf_$(CONF_VERSION): .docker_conf_build_$(CONF_VERSION)
	@echo Tagging xrobau/patched-confluence:$(CONF_VERSION)
	@docker tag confluence:$(CONF_VERSION) xrobau/patched-confluence:$(CONF_VERSION)
	@touch $@

.push_conf: .tag_conf_$(CONF_VERSION)
	@docker push xrobau/patched-confluence:$(CONF_VERSION)
	@touch $@

.tag_jira_$(JIRA_VERSION): .docker_jira_build_$(JIRA_VERSION)
	@echo Tagging xrobau/patched-jira:$(JIRA_VERSION)
	@docker tag jira:$(JIRA_VERSION) xrobau/patched-jira:$(JIRA_VERSION)
	@touch $@

.push_jira: .tag_jira_$(JIRA_VERSION)
	@docker push xrobau/patched-jira:$(JIRA_VERSION)
	@touch $@

.tag_crowd_$(CROWD_VERSION): .docker_crowd_build_$(CROWD_VERSION)
	@echo Tagging xrobau/patched-crowd:$(CROWD_VERSION)
	@docker tag crowd:$(CROWD_VERSION) xrobau/patched-crowd:$(CROWD_VERSION)
	@touch $@

.push_crowd: .tag_crowd_$(CROWD_VERSION)
	@docker push xrobau/patched-crowd:$(CROWD_VERSION)
	@touch $@

/usr/bin/docker-compose-$(COMPOSERVERSION):
	@curl -s -L "https://github.com/docker/compose/releases/download/$(COMPOSERVERSION)/docker-compose-$(shell uname -s)-$(shell uname -m)" -o $@
	@chmod 755 $@
	@rm -f /usr/bin/docker-compose
	@ln -s $@ /usr/bin/docker-compose

/usr/bin/uuid:
	apt-get -y install uuid

DIVE=0.9.2
/usr/local/bin/dive:
	# If you apt-get remove dive, it can occasonally delete /usr/local/bin.
	mkdir -p /usr/local/bin
	cd /usr/local/bin && wget https://github.com/wagoodman/dive/releases/download/v$(DIVE)/dive_$(DIVE)_linux_amd64.deb &&  apt install ./dive_$(DIVE)_linux_amd64.deb

