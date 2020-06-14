# ----------------
# Make help script
# ----------------

# Usage:
# Add help text after target name starting with '\#\#'
# A category can be added with @category. Team defaults:
# 	dev-environment
# 	docker
# 	test

# Output colors
GREEN  := $(shell tput -Txterm setaf 2)
WHITE  := $(shell tput -Txterm setaf 7)
YELLOW := $(shell tput -Txterm setaf 3)
RESET  := $(shell tput -Txterm sgr0)

# Operating System
OSFLAG :=
UNAME_S :=
DOCKERFILENAME :=
dockerfile :=
DBRESULT :=
#ifeq ($(OS),Windows_NT)
#	OSFLAG += -D WIN32
#	ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
#		OSFLAG += -D AMD64
#	endif
#	ifeq ($(PROCESSOR_ARCHITECTURE),x86)
#		OSFLAG += -D IA32
#	endif
#else
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
		OSFLAG += LINUX
		DOCKERFILENAME += "docker_compose_linux.yml"
		dockerfile += "docker_compose_linux.yml"
	endif
	ifeq ($(UNAME_S),Darwin)
		OSFLAG += OSX
		DOCKERFILENAME += "docker_compose_mac.yml"
		dockerfile += "docker_compose_mac.yml"
	endif
#endif
# Script
HELP_FUN = \
	%help; \
	while(<>) { push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z0-9\-]+)\s*:.*\#\#(?:@([a-zA-Z0-9\-]+))?\s(.*)$$/ }; \
	print "usage: make [target]\n\n"; \
	for (sort keys %help) { \
	print "${WHITE}$$_:${RESET}\n"; \
	for (@{$$help{$$_}}) { \
	$$sep = " " x (32 - length $$_->[0]); \
	print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; \
	}; \
	print "\n"; }

help:
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST) $(filter-out $@,$(MAKECMDGOALS))

phpcs_config = --ignore=**/node_modules/*,*.min.js,*.css,*features.*.inc,*.svg,*.jpg,*.png,*.json,*.woff*,*.ttf,*.md,*.sh,AltTextBehavior.class.php
coder_sniffer_path = /var/www/vendor/drupal/coder/coder_sniffer
project_root = /var/www
drupal_root = $(project_root)/docroot
custom_module_location = $(drupal_root)/sites/all/modules/custom/
custom_theme_location = $(drupal_root)/sites/all/themes/custom/
# sets URL to $PROJECT_NAME.test, and sets drush alias to $PROJECT_NAME.local
PROJECT_NAME = drupal
DIR = ${pwd}

phpcs:  ##@testing Run CodeSniffer coding standards checks
	@clear
	@clear
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/phpcs --config-set installed_paths $(coder_sniffer_path)
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/phpcs -d memory_limit=-1 --standard=drupal,drupalPractice --report-width=130 --colors $(custom_module_location) $(custom_theme_location) $(phpcs_config)

phpcbf:  ##@testing Automatically correct Coding Standards Violations
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/phpcbf --config-set installed_paths $(coder_sniffer_path)
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/phpcbf -d memory_limit=-1 --standard=drupal,drupalPractice $(custom_module_location) $(custom_theme_location) $(phpcs_config)

init: ##@initialize Initialize development environment
	@clear
	@make docker-up
	@make composer-install
	@sleep 5
	@docker-compose -f docker-compose.yml -f ${dockerfile} exec php /bin/bash -c "mkdir -p $(drupal_root)/sites/default/files/private"
	#@if [ ! "$(shell docker-compose -f docker-compose.yml -f ${dockerfile} exec -T db mysqlshow --user=drupal --password=drupal drupal | grep watchdog | grep -o watchdog)" == "watchdog" ]; then make initialize-db; echo "table not found"; else echo "table found"; fi
	#@if [ ! -f ./drush/sites/drupal.site.yml ]; then cp ./drush/sites/site.yml.example ./drush/sites/drupal.site.yml; fi
	#@make updb
	#@make log-sanitize
	#@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local sset system.maintenance_mode 0
	#@make cache-reset
initialize-db:
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local si standard --db-url=mysql://drupal:drupal@db/drupal --account-name=admin --account-pass=admin --site-name=\"Drupal Test Site\" -y
devclean: ##@initialize Halts Docker and deletes project related volumes (destroys database and drupal install)
	@clear
	@docker-compose -f docker-compose.yml -f ${dockerfile} down --volumes
	@docker volume ls

import-config: ##@drush Import Configuration Manager yaml files
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local cim vcs -y
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local csim dev -y

export-config: ##@drush Export Configuration Manager yaml files
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local cex -y
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local csex dev -y

composer-install: ##@composer Run Composer Install
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php composer install --working-dir=$(project_root)

composer-update: ##@composer Run Composer Update
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php composer update --working-dir=$(project_root)

docker-up: ##@docker Run Docker Compose Up
#ifdef TRAVIS
#	@docker-compose -f docker-compose.yml -f docker-compose-travis.yml up -d --build
#else
	@docker-compose -f docker-compose.yml -f $(dockerfile) up -d --build
#endif
docker-down: ##@docker Run Docker Compose down
	@docker-compose -f docker-compose.yml -f $(dockerfile) down

cache-reset: ##@drush run drush cache-reset
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local cr

updb: ##@drush run drush updb
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local updb -y

uli: ##@drush run drush uli
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local uli -y

dr: ##@drush Run drush commands. E.g. `make dr uli`.
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php $(project_root)/vendor/bin/drush @$(PROJECT_NAME).local $(filter-out $@,$(MAKECMDGOALS))

gao-profile-setup: $(skipfiles) #hidden target to consolidate steps needed in devinit and prodinit
	@make setos
	## The following is done because nginx spawns child processes that are not running as root, and are blocked from writing to the files directory due to file permissions issues
	@make import-db
	#@make initialize-db
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php /bin/bash -c "chmod a+w $(drupal_root)/sites/default"
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php /bin/bash -c "mkdir -p $(drupal_root)/default/files"
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php /bin/bash -c "chmod a+w $(drupal_root)/sites/default/files"
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php /bin/bash -c "mkdir -p $(drupal_root)/sites/default/files/assets"
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec php /bin/bash -c "chmod a+w $(drupal_root)/sites/default/files/assets"
	@if [ "${skipfiles}" != "true" ]; then make import-files; fi
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec drupal.test /bin/bash -c "chmod -Rf a+w $(drupal_root)/sites/default/files"
	@make cache-reset

behat:  ##@testing Execute Behat Test Suite
	@make setos
ifdef TRAVIS
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/behat -c $(project_root)/tests/behat/behat.yml -p local --tags=~@skip --colors -f progress
else
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/behat -c $(project_root)/tests/behat/behat.yml -p local --tags=~@skip --colors
endif

behat-wip: ##@testing Execute Behat Tests tagged with @wip
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/behat -c $(project_root)/tests/behat/behat.yml -p local --tags=@wip --colors -f progress

wcag2AA:  ##@testing Running Pa11y-CI tool for wcag2AA compliance against URLS in tests/pa11y/config.json
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) run pa11y /bin/bash -c "pa11y-ci --config /workspace/wcag2-config.json"

wcag2AA-url: ##@testing Running Pa11y-CI tool for wcag2AA compliance against a specified URL, which is passed in as a parameter.
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) run pa11y /bin/bash -c "pa11y-ci $(filter-out $@,$(MAKECMDGOALS))"

phpunit:  ##@testing Running Drupal Unit tests
	@make setos
	@docker-compose -f docker-compose.yml -f $(dockerfile) exec -T php $(project_root)/vendor/bin/phpunit -c $(project_root)/phpunit.xml.dist

test:  ##@testing Execute all test suites
	@make phpcs
	@make phpunit
	@make behat
	@make wcag2AA


# https://stackoverflow.com/a/6273809/1826109
%: ## result when make target does not exist
	@: