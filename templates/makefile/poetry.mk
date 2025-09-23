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

DIST_DIR := dist
BUILD_DIR := build
EGG_INFO_DIRS := *.egg-info
VENV_DIR := .venv
PYTHON_VER_FILE := .python-version
PYPROJECT := pyproject.toml
POETRY_LOCK := poetry.lock

SRC := src
TESTS := tests

COVERAGE_FILE := .coverage
GITIGNORE_FILE := .gitignore

BUILD_ARTIFACTS := $(DIST_DIR) $(BUILD_DIR) $(EGG_INFO_DIRS)
ENV_ARTIFACTS := $(VENV_DIR) $(STAMPS_DIR) $(PYTHON_VER_FILE)
ALL_ARTIFACTS   := $(BUILD_ARTIFACTS) $(ENV_ARTIFACTS)

DEFAULT_DEV_PKGS := pytest pytest-cov pytest-mock pytest-datafiles pytest-datadir
DEFAULT_DEV_PKGS += mypy black isort
DEFAULT_DEV_PKGS += pylint pylint_junit


$(STAMPS_DIR):
	@mkdir -p $@

# add line and preserve uniqueness of the file,
# useful for gitignore and a-like
define add_line
    if ! grep -Fxq "$(1)" "$(2)" 2>/dev/null; then \
        echo "$(1)" >> "$(2)"; \
        sort --unique --output "$(2)"{,}; \
    fi
endef

# del line and preserve uniqueness of the file,
# useful for gitignore and a-like
define del_line
    if [ -e "$(2)" ]; then \
        sed --in-place "/^$(1)\$$/d" "$(2)"; \
        sort --unique --output "$(2)"{,}; \
    fi
endef

### Help

.PHONY: help
help: ### Show this help message
	@grep -E '^(###[ ]{1,}.*|[a-zA-Z0-9_-]+:.*###)' $(MAKEFILE_LIST) \
		| sed -E 's/^### (.*)/\n$(BOLD)$(BLUE)\1$(RESET)/' \
		| sed -E 's/^([a-zA-Z0-9_-]+):.*###(.*)/$(GREEN)\1$(RESET):\2/' \
		| while IFS= read -r line; do printf "%b\n" "$$line"; done

### Environment management

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

.PHONY: warn-python-version
warn-python-version: ### Warn if active Python version differs from .python-version
	@if [ -f $(PYTHON_VER_FILE) ]; then \
		REQ_VER=$$(cat $(PYTHON_VER_FILE)); \
		CUR_VER=$$(poetry run python -V 2>/dev/null | awk '{print $$2}' | cut -d+ -f1 || true); \
		if [ -n "$$CUR_VER" ] && [ "$$REQ_VER" != "$$CUR_VER" ]; then \
		printf "%b\n" "$(RED)WARNING: .python-version requires $$REQ_VER but active Poetry env is $$CUR_VER$(RESET)"; \
	fi; \
	fi

### Testing

.PHONY: test
test: ### Run all tests
	poetry run pytest
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

.PHONY: test-cov
test-cov: ### Run tests with coverage report
	poetry run pytest --cov=$(src) --cov-report=term-missing
	@$(call add_line,.coverage,$(gitignore))
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

### Quality Checks

.PHONY: lint
lint: ### Run linters (black, isort, pylint)
	poetry run black --check .
	poetry run isort --check-only .
	poetry run ruff check .
	poetry run pylint $(SRC)
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

.PHONY: format
format: ### Auto-format code (black + isort)
	poetry run black .
	poetry run isort .
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

.PHONY: typecheck
typecheck: ### Run static type checks
	poetry run mypy .
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

### Composite Targets

.PHONY: qa
qa: lint typecheck ### Run all quality checks
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

.PHONY: ci
ci: qa test-cov ### Full CI suite: quality + tests with coverage
	@printf "%b\n" "$(BOLD)$(GREEN)$@ completed$(RESET)"

### Clean

.PHONY: clean-build
clean-build: ### Remove build artefacts only
	@printf "%b\n" "$(BOLD)$(BLUE)Cleaning build artefacts...$(RESET)"
	rm -rf $(BUILD_ARTIFACTS)

.PHONY: clean-env
clean-env: warn-python-version ### Remove environment artefacts only
	@printf "%b\n" "$(BOLD)$(BLUE)Cleaning environment artefacts...$(RESET)"
	rm -rf $(ENV_ARTIFACTS)

.PHONY: clean
clean: clean-build clean-env ### Remove all artefacts

.PHONY: clean
clean: ### Remove venv, stamps, and build artifacts
	@printf "%b\n" "$(BOLD)$(BLUE)Cleaning project environment...$(RESET)"
	rm -rf $(STAMPS_DIR) $(PYTHON_VER_FILE) .venv dist build *.egg-info
