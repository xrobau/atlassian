# Things you may want to change:
#   Suffix of the tag used when pushing to the docker hub below
TAGSUFFIX=-2

# Prefix for the dockerhub. If you're pushing to your own, change
# this - eg if you use HUBDEST=hub.example.com/awesome the
# tags will be:
#    hub.example.com/awesome/patched-jira:8.22.2-1
# (Assuming TAGSUFFIX is -1 and JIRA_VERSION is 8.22.2)
#
# It will ALSO explicitly tag :latest too, which can then be used
# for automated testing
HUBDEST=xrobau

# Default container to tail or enter when 'make start' or 'make shell' is run
DEFAULT=crowd

# https://www.atlassian.com/software/jira/core/download
JIRA_VERSION=9.0.0
# https://www.atlassian.com/software/crowd/download-archive
CROWD_VERSION=5.0.1
# https://www.atlassian.com/software/confluence/download-archives
CONF_VERSION=7.18.2
# https://www.atlassian.com/software/bitbucket/download-archives
BB_VERSION=8.2.0

JIRA_FILE=atlassian-jira-software-$(JIRA_VERSION)-x64.bin
JIRA_URL=https://product-downloads.atlassian.com/software/jira/downloads/$(JIRA_FILE)
JIRA_ARGS=--build-arg JIRA_VERSION=$(JIRA_VERSION) --build-arg JIRA_FILE=$(JIRA_FILE) --build-arg JIRA_URL=$(JIRA_URL)

CROWD_FILE=atlassian-crowd-$(CROWD_VERSION).tar.gz
CROWD_SRCURL=https://product-downloads.atlassian.com/software/crowd/downloads/$(CROWD_FILE)
CROWD_ARGS=--build-arg CROWD_VERSION=$(CROWD_VERSION) --build-arg CROWD_FILE=$(CROWD_FILE) --build-arg CROWD_SRCURL=$(CROWD_SRCURL)

CONF_FILE=atlassian-confluence-$(CONF_VERSION)-x64.bin
CONF_SRCURL=https://product-downloads.atlassian.com/software/confluence/downloads/$(CONF_FILE)
CONF_ARGS=--build-arg VERSION=$(CONF_VERSION) --build-arg FILE=$(CONF_FILE) --build-arg SRCURL=$(CONF_SRCURL) --build-arg PKG=confluence

BB_FILE=atlassian-bitbucket-$(BB_VERSION)-x64.bin
BB_SRCURL=https://product-downloads.atlassian.com/software/stash/downloads/$(BB_FILE)
BB_ARGS=--build-arg VERSION=$(BB_VERSION) --build-arg FILE=$(BB_FILE) --build-arg SRCURL=$(BB_SRCURL) --build-arg PKG=bitbucket

# You probably don't want to change these, unless you're debugging
# stuff that is strangely broken.
#
# Unique identifier used with docker-compose
PROJECT=atlassian
# Simply to identify the build if multiple people are
# working on it. If you're not me, you can ignore this.
USERNAME=atlassian

VOLUMES=-v $(shell pwd)/debug:/usr/local/debug

COMPOSERVERSION=1.29.2
DOCKERFILE=docker-compose.yml
SHELL=/bin/bash

.PHONY: help
help: | setup
	@echo "This builds the entire Atlassian Ecosystem as docker containers."
	@echo "  make build      Builds/updates every container"
	@echo "  make refresh    Rebuilds the base container from scratch"
	@echo "       This refreshes the base FROM image in base/Dockerfile, which"
	@echo "       invalidates the cached child containers so they will be"
	@echo "       completely updated on next 'make build'."
	@echo "       This should be used semi-regularly to ensure everything is"
	@echo "       up to date in both the OS and Java"
	@echo "  make start      Starts all containers using example compose file"
	@echo "  make stop       Stops all containers created by example compose file"
	@echo "  make psql       Starts Postgres container and runs psql"
	@echo "  make creates    Generate SQL CREATE commands to paste into psql"
	@echo "       Note this generates a random password for each service on"
	@echo "       first run, and keeps it. To change the password source nonce,"
	@echo "       delete the .uuid file."
	@echo "  make push       If you're xrobau, this will tag everything and send"
	@echo "       it to dockerhub. If you're NOT xrobau, edit HUBDEST in this"
	@echo "       Makefile to change the destination"
	@echo "  make clean      Deletes all temp files APART FROM password nonce"
	@echo "       If you want to regen your passwords, delete the .uuid file too"
	@echo "  make nuke       Stops all containers, deletes all temp files, and then"
	@echo "       deletes all local volumes. If you were wondering what a catastrophic"
	@echo "       data loss looks like, this is a great way to simulate everything"
	@echo "       being cryptolocked or rm -rf'ed. Don't do this unless you're CERTAIN"
	@echo "       THAT YOU WANT TO DELETE EVERYTHING PERMANENTLY"

.PHONY: setup
setup: /usr/bin/docker-compose-$(COMPOSERVERSION) /usr/bin/uuid /usr/local/bin/dive

.PHONY: clean
clean:
	@echo -n "Cleaning: "; \
		for f in .docker_* .push_* .tag_*; do \
			[ -e $$f ] && (echo -n "$$f "; rm -f $$f); \
		done; \
		echo ""
.PHONY: nuke
# docker volume rm displays the volume it's deleting, which is handy
nuke: stop clean
	@read -e -p "Are you certain you want to delete all persistant data? [yN] " p; \
		R=$$(echo $$p | tr '[:upper:]' '[:lower:]' | cut -c1); \
                if [ "$$R" == "y" ]; then \
			for v in $(shell docker volume ls -q | grep ^$(PROJECT)); do \
				echo -n "Nuking "; \
				docker volume rm $$v; \
			done; \
		fi

.PHONY: start
start: build | setup
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

.PHONY: refresh
refresh:
	@SRC=$$(awk '/FROM/ { print $$2 }' base/Dockerfile); \
		echo Updating $$SRC; \
		docker pull $$SRC; \
		docker build --no-cache --tag atlassian-base:latest base/; \
		touch .docker_base_build

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
	@echo Tagging $(HUBDEST)/atlassian-base:$(RELEASE)$(TAGSUFFIX)
	@docker tag atlassian-base:latest $(HUBDEST)/atlassian-base:$(RELEASE)
	@touch $@

.push_base: .tag_base
	$(eval RELEASE=$(USERNAME)-$(shell cat .lastbuild)-$(shell cat .buildnumber))
	docker push $(HUBDEST)/atlassian-base:$(RELEASE)
	touch $@

.tag_bb_$(BB_VERSION)$(TAGSUFFIX): .docker_bb_build_$(BB_VERSION)
	@echo Tagging $(HUBDEST)/patched-bitbucket:$(BB_VERSION)$(TAGSUFFIX)
	@docker tag bitbucket:$(BB_VERSION) $(HUBDEST)/patched-bitbucket:$(BB_VERSION)$(TAGSUFFIX)
	@touch $@

.push_bb: .tag_bb_$(BB_VERSION)$(TAGSUFFIX)
	@docker push $(HUBDEST)/patched-bitbucket:$(BB_VERSION)$(TAGSUFFIX)
	@touch $@

.tag_conf_$(CONF_VERSION)$(TAGSUFFIX): .docker_conf_build_$(CONF_VERSION)
	@echo Tagging $(HUBDEST)/patched-confluence:$(CONF_VERSION)$(TAGSUFFIX)
	@docker tag confluence:$(CONF_VERSION) $(HUBDEST)/patched-confluence:$(CONF_VERSION)$(TAGSUFFIX)
	@touch $@

.push_conf: .tag_conf_$(CONF_VERSION)$(TAGSUFFIX)
	@docker push $(HUBDEST)/patched-confluence:$(CONF_VERSION)$(TAGSUFFIX)
	@touch $@

.tag_jira_$(JIRA_VERSION)$(TAGSUFFIX): .docker_jira_build_$(JIRA_VERSION)
	@echo Tagging $(HUBDEST)/patched-jira:$(JIRA_VERSION)$(TAGSUFFIX)
	@docker tag jira:$(JIRA_VERSION) $(HUBDEST)/patched-jira:$(JIRA_VERSION)$(TAGSUFFIX)
	@touch $@

.push_jira: .tag_jira_$(JIRA_VERSION)$(TAGSUFFIX)
	@docker push $(HUBDEST)/patched-jira:$(JIRA_VERSION)$(TAGSUFFIX)
	@touch $@

.tag_crowd_$(CROWD_VERSION)$(TAGSUFFIX): .docker_crowd_build_$(CROWD_VERSION)
	@echo Tagging $(HUBDEST)/patched-crowd:$(CROWD_VERSION)$(TAGSUFFIX)
	@docker tag crowd:$(CROWD_VERSION) $(HUBDEST)/patched-crowd:$(CROWD_VERSION)$(TAGSUFFIX)
	@touch $@

.push_crowd: .tag_crowd_$(CROWD_VERSION)$(TAGSUFFIX)
	@docker push $(HUBDEST)/patched-crowd:$(CROWD_VERSION)$(TAGSUFFIX)
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

