DOCKER=docker
COMPOSE=docker-compose
APP_NAME=interactivemap
STATIC_APP_NAME=imap_static
DB_SERVER=imap_pg

# import config.
# You can change the default config with `make cnf="config_special.env" build`
cnf ?= prod.env
include $(cnf)
export $(shell sed 's/=.*//' $(cnf))

# import deploy config
# You can change the default deploy config with `make cnf="deploy_special.env" release`
dpl ?= deploy.env
include $(dpl)
export $(shell sed 's/=.*//' $(dpl))

# grep the version from the mix file
VERSION=$(shell ./bin/version.sh)

FRONTEND_REPO=${PATH_TO_FRONTEND_REPO}

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help


# DOCKER TASKS

# Build the container

image_app:
	$(DOCKER) build -t $(APP_NAME) .

image_static:
	$(DOCKER) build -t $(STATIC_APP_NAME) $(FRONTEND_REPO)

image: image_app image_static

run: stop
	$(COMPOSE) up --build -d

# Build and run the container
up: ## Spin up the project with the database and static server
	$(COMPOSE) up --build --abort-on-container-exit

app: ## Spin up the project
	$(COMPOSE) up --build $(APP_NAME)

stop: ## Stop running containers
	$(DOCKER) stop $(STATIC_APP_NAME)
	$(DOCKER) stop $(APP_NAME)
	$(DOCKER) stop $(DB_SERVER)

rm: stop ## Stop and remove running containers
	$(DOCKER) rm $(APP_NAME)

export_app:
	$(DOCKER) save $(APP_NAME) > $(IMAGE_SAVE_DIR)/$(APP_NAME).tar
export_static:
	$(DOCKER) save $(STATIC_APP_NAME) > $(IMAGE_SAVE_DIR)/$(STATIC_APP_NAME).tar

export: export_app export_static

import_app:
	$(DOCKER) load -i $(REMOTE_IMAGE_DIR)/$(APP_NAME).tar

import_static:
	$(DOCKER) load -i $(REMOTE_IMAGE_DIR)/$(STATIC_APP_NAME).tar

import: import_app import_static

upload_app:
	rsync -azP $(IMAGE_SAVE_DIR)/$(APP_NAME).tar $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_IMAGE_DIR)/$(APP_NAME).tar

upload_static:
	rsync -azP $(IMAGE_SAVE_DIR)/$(STATIC_APP_NAME).tar $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_IMAGE_DIR)/$(STATIC_APP_NAME).tar

upload: upload_static upload_app

# Docker release - build, tag and push the container
release: build publish ## Make a release by building and publishing the `{version}` ans `latest` tagged containers to ECR

# Docker publish
publish: repo-login publish-latest publish-version ## publish the `{version}` ans `latest` tagged containers to ECR

publish-latest: tag-latest ## publish the `latest` taged container to ECR
	@echo 'publish latest to $(DOCKER_REPO)'
	$(DOCKER) push $(DOCKER_REPO)/$(APP_NAME):latest

publish-version: tag-version ## publish the `{version}` taged container to ECR
	@echo 'publish $(VERSION) to $(DOCKER_REPO)'
	$(DOCKER) push $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

# Docker tagging
tag: tag-latest tag-version ## Generate container tags for the `{version}` ans `latest` tags

tag-latest: ## Generate container `{version}` tag
	@echo 'create tag latest'
	$(DOCKER) tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):latest

tag-version: ## Generate container `latest` tag
	@echo 'create tag $(VERSION)'
	$(DOCKER) tag $(APP_NAME) $(DOCKER_REPO)/$(APP_NAME):$(VERSION)

version: ## output to version
	@echo $(VERSION)
