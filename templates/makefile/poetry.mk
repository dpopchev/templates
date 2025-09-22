MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --check-symlink-times

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

.DEFAULT_GOAL := help

BOLD   := \\033[1m
BLUE   := \\033[34m
GREEN  := \\033[32m
RED    := \\033[31m
RESET  := \\033[0m

STAMPS_DIR  := .stamps
BOOTSTRAP_STAMP := $(STAMPS_DIR)/boostrap.stamp

DEFAULT_PY := $(shell command -v python3)
PYTHON_VER_FILE := .python-version
PYPROJECT := pyproject.toml
POETRY_LOCK := poetry.lock

DEFAULT_DEV_PKGS := pytest pytest-cov pytest-mock pytest-datafiles pytest-datadir
DEFAULT_DEV_PKGS += mypy black isort
DEFAULT_DEV_PKGS += pylint pylint_junit

$(STAMPS_DIR):
	@mkdir -p $@

### Help

.PHONY: help
help: ### Show this help message
	@grep -E '^(###[ ]{1,}.*|[a-zA-Z0-9_-]+:.*###)' $(MAKEFILE_LIST) \
		| sed -E 's/^### (.*)/\n$(BOLD)$(BLUE)\1$(RESET)/' \
		| sed -E 's/^([a-zA-Z0-9_-]+):.*###(.*)/$(GREEN)\1$(RESET):\2/' \
		| while IFS= read -r line; do printf "%b\n" "$$line"; done

### Environment bootstrap

.PHONY: bootstrap
bootstrap: ### Bootstrap poetry project with venv in-project and .python-version
bootstrap: $(BOOTSTRAP_STAMP)

$(BOOTSTRAP_STAMP): $(PYTHON_VER_FILE) $(PYPROJECT) $(POETRY_LOCK) | $(STAMPS_DIR)
	@printf "%b\n" "$(BOLD)$(BLUE)Configuring Poetry...$(RESET)"
	poetry config virtualenvs.in-project true
	poetry env use $$(cat $(PYTHON_VER_FILE))
	poetry sync --only main
	@touch $@

$(PYTHON_VER_FILE): | $(STAMPS_DIR)
	@printf "%b " "$(BOLD)$(BLUE)Choose Python$(RESET) [$(GREEN)$(DEFAULT_PY)]$(RESET)"
	@read -r PY; \
	if [ -z "$$PY" ]; then PY="$(DEFAULT_PY)"; fi; \
	PY_PATH=$$(command -v $$PY || true); \
	if [ -z "$$PY_PATH" ] || [ ! -x "$$PY_PATH" ]; then \
		printf "%b\n" "$(RED)Error: $$PY is not an executable file$(RESET)"; \
		exit 1; \
	fi; \
	PY_VER=$$($$PY_PATH -V | awk '{print $$2}'); \
	echo "$$PY_VER" > $@; \

$(PYPROJECT):
	poetry init
	poetry lock

$(POETRY_LOCK): $(PYPROJECT)
	@if [ ! -f $@ ]; then \
		printf "%b\n" "$(BOLD)$(BLUE)Lock file missing — generating$(RESET)"; \
		poetry lock --regenerate; \
	elif ! poetry check --lock >/dev/null 2>&1; then \
		printf "%b\n" "$(BOLD)$(BLUE)Lock file out of date — regenerating$(RESET)"; \
		poetry lock; \
	else \
		printf "%b\n" "$(BOLD)$(GREEN)Lock file is up to date$(RESET)"; \
	fi

.PHONY: dev
dev: ### Add the dev group
	@if ! poetry show --group dev >/dev/null 2>&1; then poetry add --group dev $(DEFAULT_DEV_PKGS); fi
	poetry install --only dev
