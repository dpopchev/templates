.SUFFIXES:
.DELETE_ON_ERROR:

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
MAKEFLAGS += --output-sync=target
MAKEFLAGS += --check-symlink-times

.DEFAULT_GOAL := help

DEFAULT_DEV_PKGS := pytest pytest-cov pytest-mock pytest-datafiles pytest-datadir
DEFAULT_DEV_PKGS += mypy black isort
DEFAULT_DEV_PKGS += pylint pylint_junit

DEFAULT_JUPYTER_PKGS := jupyterlab-vim jupyterlab-lsp jupytext jupyterlab

DEFAULT_TENSORBOARD_PKGS := tensorboard

SELF_CHECK_TARGETS := bootstrap venv lock
SELF_CHECK_TARGETS += install install-dev install-all
SELF_CHECK_TARGETS += update update-all sync
SELF_CHECK_TARGETS += setup setup-dev setup-all
SELF_CHECK_TARGETS += install-jupyter run-jupyter
SELF_CHECK_TARGETS += install-tensorboard run-tensorboard
SELF_CHECK_TARGETS += lint format typecheck test coverage quality
SELF_CHECK_TARGETS += clean

# ANSI codes for pretty print
# example usage: $(BOLD)$(BLUE) this text $(RESET) something else
BOLD   := \\033[1m
BLUE   := \\033[34m
GREEN  := \\033[32m
RED    := \\033[31m
RESET  := \\033[0m

log = printf "%b\n" "$(BOLD)$(1)$(2)$(RESET)"
log_info = $(call log,$(BLUE),$(1))
log_ok = $(call log,$(GREEN),$(1))
log_nok = $(call log,$(RED),$(1))

DEFAULT_PY := $(shell command -v python3)
PYMANAGER := poetry
SRC_DIR := src
TESTS_DIR := tests
GITIGNORE := .gitignore
NOTEBOOKS_DIR := notebooks
WORKDIR := workdir
TENSORBOARDLOGS := $(WORKDIR)/tensorboard
DIST_DIR := dist
DOTENV := .env
DOTENV_EXAMPLE := .env.example

# Docker
DOCKERFILE := Dockerfile
IMAGE_NAME ?= $(notdir $(CURDIR))
IMAGE_TAG ?= latest
DOCKER_IMAGE := $(DIST_DIR)/docker_$(IMAGE_NAME)-$(IMAGE_TAG).tar
COMPOSE_FILE := docker-compose.yml
DOCKER_COMPOSE ?= podman-compose

# Project metadata
PYPROJECT := pyproject.toml
LOCKFILE := poetry.lock
PYVER := .python-version
VENV := .venv
README := README.md

# Stamps
STAMPS_DIR := .stamps
STAMP_PYVER := $(STAMPS_DIR)/python-version.stamp

$(STAMPS_DIR) $(WORKDIR) $(DIST_DIR):
	@mkdir -p $@
	@$(call add_line,$@/,$(GITIGNORE))

$(SRC_DIR):
	@mkdir -p $@/$(notdir $(CURDIR))
	@touch $@/$(notdir $(CURDIR))/__init__.py

$(TESTS_DIR):
	@mkdir -p $@
	@touch $@/__init__.py

$(NOTEBOOKS_DIR):
	@mkdir -p $@

define add_line
	if ! grep -Fxq "$(1)" "$(2)" 2>/dev/null; then \
		echo "$(1)" >> "$(2)"; \
		awk '!seen[$$0]++' "$(2)" > "$(2).tmp" && mv "$(2).tmp" "$(2)"; \
	fi
endef

define del_line
	if [ -e "$(2)" ]; then \
		grep -Fxv "$(1)" "$(2)" | awk '!seen[$$0]++' > "$(2).tmp"; \
		mv "$(2).tmp" "$(2)"; \
	fi
endef

### Project Management

.PHONY: bootstrap
bootstrap: ### Scaffold project (set python-version; create pyproject, lockfile, README and directory layout)
bootstrap: $(PYVER) $(PYPROJECT) $(LOCKFILE) $(README) $(SRC_DIR) $(TESTS_DIR)
bootstrap: $(GITIGNORE)

.PHONY: venv
venv: $(VENV) ### Refresh virtual environment (sync with python-version and lockfile)

$(VENV): $(STAMP_PYVER) | $(STAMPS_DIR)
	@$(call log_info,Creating virtual environment...)
	$(PYMANAGER) config virtualenvs.in-project true
	$(PYMANAGER) env use $$(cat $(PYVER))
	@$(call add_line,$(VENV)/,$(GITIGNORE))
	@$(call log_ok,Virtual environment ready)

$(STAMP_PYVER): $(PYVER) | $(STAMPS_DIR)
	@$(call log_info,Checking Python version...)
	@if [ -d $(VENV) ]; then \
		CURRENT=$$($(VENV)/bin/python -V 2>/dev/null || echo none); \
		REQUIRED="Python $$(cat $(PYVER))"; \
		if [ "$$CURRENT" != "$$REQUIRED" ]; then \
		$(call log_nok,Python version drift \($$CURRENT vs $$REQUIRED\), removing $(VENV)); \
		rm -rf $(VENV); \
	else \
		$(call log_ok,Virtualenv Python version matches expectations); \
	fi; \
	fi
	@touch $@

$(LOCKFILE): $(PYPROJECT)
	@$(call log_info,Generating lockfile...)
	$(PYMANAGER) lock
	@$(call log_ok,Created $@)

$(PYVER):
	@$(call log_info,Choose Python interpreter $(RESET)[$(GREEN)$(DEFAULT_PY)$(RESET)]: )
	@read -r PY; \
		if [ -z "$$PY" ]; then PY="$(DEFAULT_PY)"; fi; \
		PY_PATH=$$(command -v $$PY || true); \
		if [ -z "$$PY_PATH" ] || [ ! -x "$$PY_PATH" ]; then \
		$(call log_nok,Python interpreter error: $$PY not executable); \
		exit 1; \
		fi; \
	PY_VER=$$($$PY_PATH -V | awk '{print $$2}'); \
	echo "$$PY_VER" > $@;

$(PYPROJECT):
	$(PYMANAGER) init

$(README):
	@echo "# $(notdir $(CURDIR))" > $@
	@echo "Elevator pitch." >> $@
	@echo "" >> $@
	@echo "## Install" >> $@
	@echo '```bash' >> $@
	@echo "git clone --depth 1 <URL>" >> $@
	@echo "cd $(notdir $(CURDIR))" >> $@
	@echo "make setup # see help for more" >> $@
	@echo '```' >> $@
	@echo "If more context is needed then rename section to \`Installation\`." >> $@
	@echo "Put details into \`Requirements\` and \`Install\` subsections." >> $@
	@echo "" >> $@
	@echo "## Usage" >> $@
	@echo "Place examples with expected output." >> $@
	@echo "Start with \`Setup\` subsection for configuration." >> $@
	@echo "Break into subsections using scenario/feature names." >> $@
	@echo "" >> $@
	@echo "## Acknowledgment" >> $@
	@echo "- [makeareadme](https://www.makeareadme.com/)" >> $@
	@echo "" >> $@
	@$(call log_ok,$@ template created)

$(GITIGNORE):
	@$(call add_line,.venv/,$@)
	@$(call add_line,__pycache__/,$@)
	@$(call add_line,*.py[cod],$@)
	@$(call add_line,*.egg-info/,$@)
	@$(call add_line,build/,$@)
	@$(call add_line,dist/,$@)
	@$(call add_line,.coverage,$@)
	@$(call add_line,htmlcov/,$@)
	@$(call add_line,.mypy_cache/,$@)
	@$(call add_line,.pytest_cache/,$@)
	@$(call log_ok,$@ created)

.PHONY: lock
lock: $(LOCKFILE) ### Regenerate lockfile from pyproject

### Dependency Management

.PHONY: install
install: venv $(PYPROJECT) $(LOCKFILE) ### Install runtime (main) dependencies
	@$(call log_info,Installing only runtime dependencies...)
	$(PYMANAGER) install --only main
	@$(call log_ok,Runtime dependencies installed)

.PHONY: install-%
install-%: venv $(PYPROJECT) $(LOCKFILE) ### Install dependencies for group '%'
	@$(call log_info,Installing dependencies for group '$*'...)
	$(PYMANAGER) install --with $*
	@$(call log_ok,Dependencies for group '$*' installed)

.PHONY: install-all
install-all: venv $(PYPROJECT) $(LOCKFILE) ### Install all groups of dependencies
	@$(call log_info,Installing all dependencies...)
	$(PYMANAGER) install
	@$(call log_ok,All dependencies installed)

.PHONY: install-dev
install-dev: venv $(PYPROJECT) $(LOCKFILE) ### Install dependencies for dev group
	@$(call log_info,Installing dependencies for dev group...)
	@if ! grep -Eq '^\[tool.poetry.group.dev(\.dependencies)?\]' $(PYPROJECT); then $(PYMANAGER) add --group dev $(DEFAULT_DEV_PKGS); fi
	$(PYMANAGER) install --with dev
	@$(call log_ok,Dependencies for group dev installed)

.PHONY: install-jupyter
install-jupyter: venv $(PYPROJECT) $(LOCKFILE) ### Install dependencies for jupyter group
	@$(call log_info,Installing jupyter notebook...)
	@if ! grep -Eq '^\[tool.poetry.group.jupyter(\.dependencies)?\]' $(PYPROJECT); then $(PYMANAGER) add --group jupyter $(DEFAULT_JUPYTER_PKGS); fi
	$(PYMANAGER) install --with jupyter
	@$(call log_ok,Dependencies for group jupyter installed)

.PHONY: install-tensorboard
install-tensorboard: venv $(PYPROJECT) $(LOCKFILE) ### Install dependencies for tensorboard group
	@$(call log_info,Installing tensorboard...)
	@if ! grep -Eq '^\[tool.poetry.group.tensorboard(\.dependencies)?\]' $(PYPROJECT); then $(PYMANAGER) add --group tensorboard $(DEFAULT_TENSORBOARD_PKGS); fi
	$(PYMANAGER) install --with tensorboard
	@$(call log_ok,Dependencies for group tensorboard installed)

.PHONY: update
update: $(PYPROJECT) ### Update main dependencies (resolve new versions) and refresh venv
	@$(call log_info,Updating dependencies to latest allowed versions)
	$(PYMANAGER) update --only main
	@$(MAKE) install
	@$(call log_ok,Dependencies updated)

.PHONY: update-all
update-all: $(PYPROJECT) ### Update all dependencies (resolve new versions) and refresh venv
	@$(call log_info,Updating dependencies to latest allowed versions)
	$(PYMANAGER) update
	@$(MAKE) install-all
	@$(call log_ok,Dependencies updated)

.PHONY: sync
sync: venv ### Sync environment strictly to the lockfile (no upgrades)
	@$(call log_info,Synchronizing environment with lockfile)
	$(PYMANAGER) install --sync
	@$(call log_ok,Environment synchronized)

.PHONY: setup
setup: bootstrap venv install ### Production project setup (scaffold + environment + package)

.PHONY: setup-dev
setup-dev: bootstrap venv install-dev ### Dev project setup (scaffold + environment + package + dev group)

.PHONY: setup-all
setup-all: bootstrap venv install-all ### Full project setup (scaffold + environment + package + all groups)

### Run

.PHONY: run-jupyter
run-jupyter: venv install-jupyter | $(NOTEBOOKS_DIR) ### Run jupyter lab
	$(PYMANAGER) run jupyter lab --notebook-dir=$(NOTEBOOKS_DIR)

.PHONY: run-tensorboard
run-tensorboard: venv install-tensorboard | $(WORKDIR) ### Run tensorboard lab
	$(PYMANAGER) run tensorboard --logdir $(TENSORBOARDLOGS)

### Code Quality

.PHONY: lint
lint: ### Run linters (black, isort, pylint)
	$(PYMANAGER) run black --check .
	$(PYMANAGER) run isort --check-only .
	$(PYMANAGER) run pylint $(SRC_DIR)

.PHONY: format
format: ### Auto-format code (black + isort)
	$(PYMANAGER) run black .
	$(PYMANAGER) run isort .

.PHONY: typecheck
typecheck: ### Run static type checks
	$(PYMANAGER) run mypy .

### Testing

.PHONY: test
test: ### Run all tests
	$(PYMANAGER) run pytest

.PHONY: coverage
coverage: ### Run tests with coverage report
	$(PYMANAGER) run pytest --cov=$(SRC_DIR) --cov-report=term-missing
	@$(call add_line,.coverage,$(GITIGNORE))

.PHONY: quality
quality: lint typecheck test coverage ### Run all quality checks

### Utilities-Python

.PHONY: tests-structure
tests-structure: ### Create test directories mirroring src modules
	@find $(SRC_DIR) -type f -name "*.py" ! -name "__*__.py" | while read f; do \
		p=$${f#$(SRC_DIR)/}; \
		m=$${p%.py}; \
		t=$(TESTS_DIR)/$${m}; \
		mkdir -p "$$t"; \
		$(call log_ok,Created $$t); \
		done

.PHONY: build
build: venv $(PYPROJECT) $(LOCKFILE) | $(DIST_DIR) ### Build distribution packages
	@$(call log_info,Building distribution package...)
	$(PYMANAGER) build
	@$(call log_ok,Distribution packages created at $(DIST_DIR))

.PHONY: publish
publish: build ### Publish Python package
	@$(call log_nok,Recipe not yet implemented)

.PHONY: clean-venv
clean-venv: ### Remove virtual environment and stamps
	@rm -rf $(VENV) $(STAMPS_DIR)


.PHONY: clean-build
clean-build: ### Remove build artifacts
	@rm -rf build/ $(DIST_DIR) *.egg-info

.PHONY: clean-pyc
clean-pyc: ### Remove Python cache file
	@find $(SRC_DIR) $(TESTS_DIR) -type d -name '__pycache__' -exec rm -rf {} +
	@find $(SRC_DIR) $(TESTS_DIR) -type d -name '*.py[co]' -delete

.PHONY: clean-test
clean-test: ### Remove test artifacts
	@rm -rf .pytest_cache/ .coverage htmlcov/ .mypy_cache/

### Utilities-Docker

.PHONY: podman-build
podman-build: ### Use to bypass the podman-compose if needed
	podman build -t $(IMAGE_NAME):$(IMAGE_TAG) -f $(DOCKERFILE) .

.PHONY: docker-build
docker-build: ### Build Docker image via Compose
docker-build: build env-setup $(COMPOSE_FILE)
	@$(call log_info,Building Docker image $(IMAGE_NAME):$(IMAGE_TAG)...)
	@PYVER_VAL=$$(cat $(PYVER)); \
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) build
	@$(call log_ok,Docker image saved at $@)

$(COMPOSE_FILE): | $(DOCKERFILE)
	@$(call log_info,Missing $(COMPOSE_FILE), creating default...)
	@echo 'version: "3.9"' > $@
	@echo '' >> $@
	@echo 'services:' >> $@
	@echo '  app:' >> $@
	@echo '    build:' >> $@
	@echo '      context: .' >> $@
	@echo '      dockerfile: $(DOCKERFILE)' >> $@
	@echo '      args:' >> $@
	@echo '        PYTHON_VERSION: $${PYTHON_VERSION}' >> $@
	@echo '    image: $(IMAGE_NAME):$(IMAGE_TAG)' >> $@
	@echo '    env_file:' >> $@
	@echo '      - .env' >> $@
	@echo '    environment:' >> $@
	@echo '      APP_ENV: $${APP_ENV}' >> $@
	@echo '      LOG_LEVEL: $${LOG_LEVEL}' >> $@
	@echo '      DEBUG: $${DEBUG}' >> $@
	@echo '      TZ: $${TZ}' >> $@
	@echo '      DATABASE_URL: $${DATABASE_URL}' >> $@
	@echo '      SECRET_KEY: $${SECRET_KEY}' >> $@
	@echo '      API_TOKEN: $${API_TOKEN}' >> $@
	@echo '      FEATURE_X_ENABLED: $${FEATURE_X_ENABLED}' >> $@
	@echo '      MOCK_MODE: $${MOCK_MODE}' >> $@
	@echo '    ports:' >> $@
	@echo '      - "$${PORT}:$${PORT}"' >> $@
	@echo '    volumes:' >> $@
	@echo '      - ./data:$${DATA_DIR}' >> $@
	@echo '      - $${CACHE_DIR}:/cache' >> $@
	@echo '    command: ["python", "-c", "print('\''Composed successfully!'\'')"]' >> $@
	@$(call log_ok,Default $(COMPOSE_FILE) created)

$(DOCKERFILE):
	@$(call log_info,Missing $(DOCKERFILE), creating default...)
	@echo 'ARG PYTHON_VERSION' > $@
	@echo '' >> $@
	@echo 'FROM python:$${PYTHON_VERSION}-slim-bookworm' >> $@
	@echo '' >> $@
	@echo 'RUN set -eux; apt-get update \' >> $@
	@echo '&& apt-get install --no-install-recommends -y build-essential \' >> $@
	@echo '&& apt-get clean && rm -rf /var/lib/apt/lists/*' >> $@
	@echo '' >> $@
	@echo 'WORKDIR /app' >> $@
	@echo '' >> $@
	@echo 'COPY $(DIST_DIR)/ /app/dist/' >> $@
	@echo '' >> $@
	@echo 'RUN set -eux; \' >> $@
	@echo 'LATEST=$$(ls -t /app/dist/*.whl | head -n1); \' >> $@
	@echo 'pip install --no-cache-dir "$$LATEST"; \' >> $@
	@echo 'rm -rf /app/dist/' >> $@
	@echo '' >> $@
	@echo 'CMD ["python", "-c", "print('\''Ran successfully!'\'')"]' >> $@
	@$(call log_ok,Default $(DOCKERFILE) created)

.PHONY: docker-run
docker-run: ### Run on-off container via Compose
docker-run: env-setup $(COMPOSE_FILE)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) run --rm app

.PHONY: docker-up
docker-up: ### Start services(s) via Compose
docker-up: env-setup $(COMPOSE_FILE)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) up -d

.PHONY: docker-down
docker-down: ### Stop and remove containers
docker-down: env-setup $(COMPOSE_FILE)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down

.PHONY: docker-logs
docker-logs: ### Tail logs
docker-logs: env-setup $(COMPOSE_FILE)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) logs -f

.PHONY: docker-clean
docker-clean: ### Remove images built by Compose
docker-clean: env-setup $(COMPOSE_FILE)
	@$(call log_info,Cleaning Docker artifacts...)
	$(DOCKER_COMPOSE) -f $(COMPOSE_FILE) down --rmi all --volumes --remove-orphans
	@$(call log_ok,Docker artifacts cleaned)

### Utilities-Dotenv

.PHONY: env-setup ### setup an .env and example
env-setup: $(DOTENV)

$(DOTENV): $(STAMP_PYVER) | $(DOTENV_EXAMPLE)
	@if [ ! -f $@ ]; then cp $(DOTENV_EXAMPLE) $@; fi
	@_PYVER=$$(cat $(PYVER)); \
	       sed -i.bak "s/^PYTHON_VERSION=.*/PYTHON_VERSION=$$_PYVER/" $@ && rm -f $@.bak

$(DOTENV_EXAMPLE):
	@echo "PYTHON_VERSION=$$(cat .python-version 2>/dev/null || echo 3.11)" > $@
	@echo "APP_ENV=dev" >> $@
	@echo "LOG_LEVEL=debug" >> $@
	@echo "DEBUG=true" >> $@
	@echo "TZ=UTC" >> $@
	@echo "PORT=8000" >> $@
	@echo "HOST=0.0.0.0" >> $@
	@echo "DATABASE_URL=postgresql://user:password@localhost:5432/mydb" >> $@
	@echo "SECRET_KEY=changeme" >> $@
	@echo "API_TOKEN=changeme" >> $@
	@echo "DATA_DIR=/app/data" >> $@
	@echo "CACHE_DIR=/tmp/cache" >> $@
	@echo "FEATURE_X_ENABLED=true" >> $@
	@echo "MOCK_MODE=false" >> $@
	@echo "# Add more environment variables as needed" >> $@

### Utilities

.PHONY: help
help: ### Show this help message
	@grep -E '^(###[ ]{1,}.*|[a-zA-Z0-9_-]+:.*###)' $(MAKEFILE_LIST) \
		| sed -E 's/^### (.*)/$(BOLD)$(BLUE)\1$(RESET)/' \
		| sed -E 's/^([a-zA-Z0-9_-]+):.*###(.*)/    $(GREEN)\1$(RESET):\2/' \
		| while IFS= read -r line; do printf "%b\n" "$$line"; done

.PHONY: demo-logging
demo-logging: ### logging messages demo
	@$(call log_info,What is about to be done)
	@$(call log_ok,Something successfully ended)
	@$(call log_nok,Something successfully failed)

.PHONY: selfcheck
selfcheck: ### Verify top-level Makefile targets and show recipes only if they fail
	@$(call log_info,Starting selfchecks\n-------------------\n)
	@set -e; \
	for target in $(SELF_CHECK_TARGETS); do \
		$(call log_info,Testing target: $$target); \
		if ! $(MAKE) -n $$target >/dev/null; then \
			$(call log_nok,Target '$$target' failed); \
			$(call log_info,Recipe for '$$target':); \
			$(MAKE) -n $$target | sed 's/^/    /'; \
			exit 1; \
		else \
			$(call log_ok,Target '$$target' OK); \
		fi; \
		echo ""; \
		done
	@$(call log_info,Selfcheck complete)

.PHONY: clean
clean: clean-venv clean-build clean-pyc clean-test docker-clean
