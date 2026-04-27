.SUFFIXES:
.DELETE_ON_ERROR:

SHELL       := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
MAKEFLAGS += --output-sync=target

.DEFAULT_GOAL := help

# ──────────────────────────────────────────────────────────────────────────────
# .env  — optional, never required; CI uses pipeline variable groups instead
# ──────────────────────────────────────────────────────────────────────────────

DOTENV := .env

ifneq ($(wildcard $(DOTENV)),)
  include $(DOTENV)
  export
endif

# ──────────────────────────────────────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────────────────────────────────────

BOLD   := \033[1m
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
RED    := \033[31m
RESET  := \033[0m

# Suppress --warn-undefined-variables false positives for $(call) arguments
1 :=
2 :=
3 :=

define _log_raw
	@{ \
	  _tag="[$(2)]"; \
	  _msg="$(3)"; \
	  if _c=$$(tput cols 2>/dev/null); then _cols=$$_c; else _cols=80; fi; \
	  _max=$$(( _cols - $${#_tag} - 4 )); \
	  if [ $${#_msg} -gt $$_max ] && [ $$_max -gt 0 ]; then \
	    _msg="$${_msg:0:$$_max}..."; \
	  fi; \
	  printf "$(BOLD)$(1)%s$(RESET) %s\n" "$$_tag" "$$_msg" >&2; \
	}
endef

log_info = $(call _log_raw,$(CYAN),INFO,$(1))
log_ok   = $(call _log_raw,$(GREEN),DONE,$(1))
log_warn = $(call _log_raw,$(YELLOW),WARN,$(1))
log_nok  = $(call _log_raw,$(RED),FAIL,$(1))

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────

# Override at the command line: CI=true make publish
CI ?= false

PYVER     := .python-version
VENV      := venv
PYPROJECT := pyproject.toml
SRC_DIR   := src
DIST_DIR  := dist

# Path to the Python interpreter used to create the virtual environment.
# The developer is responsible for ensuring this interpreter exists
# (install via pyenv, system packages, deadsnakes PPA, etc.).
# Override at the command line: PYTHON=/home/user/.pyenv/versions/3.12.13/bin/python make venv
PYTHON ?= python$(shell cat $(PYVER))

# ──────────────────────────────────────────────────────────────────────────────
### Environment
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: venv
venv: ## Create venv or rebuild it if .python-version has drifted
	$(call log_info,Checking Python version drift...)
	@if [ -d "$(VENV)" ]; then \
	  CURRENT=$$($(VENV)/bin/python -V 2>/dev/null || echo none); \
	  REQUIRED="Python $$(cat $(PYVER))"; \
	  if [ "$$CURRENT" = "$$REQUIRED" ]; then \
	    printf "$(BOLD)$(GREEN)%s$(RESET) %s\n" "[DONE]" "$$CURRENT matches $(PYVER) — nothing to do" >&2; \
	    exit 0; \
	  else \
	    printf "$(BOLD)$(YELLOW)%s$(RESET) %s\n" "[WARN]" "Drift — venv=$$CURRENT expected=$$REQUIRED, removing $(VENV)" >&2; \
	    rm -rf $(VENV); \
	  fi; \
	fi
	$(call log_info,Creating virtual environment $(VENV) using $(PYTHON)...)
	@$(PYTHON) -m venv $(VENV)
	$(call log_ok,Virtual environment ready)

# ──────────────────────────────────────────────────────────────────────────────
### Dependencies
# ──────────────────────────────────────────────────────────────────────────────

# Poetry respects VIRTUAL_ENV when set — it will install into the active venv
# instead of creating or using its own managed environment.

.PHONY: install
install: venv ## Install all dependencies (main + dev groups)
	$(call log_info,Installing all dependencies...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry install
	$(call log_ok,Done)

.PHONY: install-prod
install-prod: venv ## Install production dependencies only (main group)
	$(call log_info,Installing production dependencies...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry install --only main
	$(call log_ok,Done)

.PHONY: sync
sync: venv ## Reconcile environment to lockfile (keeps existing venv)
	$(call log_info,Syncing to lockfile...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry install --sync
	$(call log_ok,Done)

.PHONY: update
update: ## Resolve and update all dependencies, regenerate lockfile
	$(call log_info,Updating dependencies...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry update
	$(call log_ok,Lockfile updated — run make install to apply)

.PHONY: reset
reset: clean ## Nuke everything and rebuild cleanly from lockfile
	$(call log_info,Resetting environment from lockfile...)
	@$(PYTHON) -m venv $(VENV)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry install --sync
	$(call log_ok,Environment reset complete)

# ──────────────────────────────────────────────────────────────────────────────
### Code Quality
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: format
format: ## Auto-format with ruff (format + fix)
	$(call log_info,Formatting...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry run ruff format .
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry run ruff check --fix .
	$(call log_ok,Done)

.PHONY: lint
lint: ## Lint with ruff — no auto-fix
	$(call log_info,Linting...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry run ruff check .
	$(call log_ok,Done)

.PHONY: typecheck
typecheck: ## Static type check with mypy
	$(call log_info,Type checking...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry run mypy .
	$(call log_ok,Done)

.PHONY: test
test: ## Run pytest suite
	$(call log_info,Running tests...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry run pytest
	$(call log_ok,Done)

.PHONY: coverage
coverage: ## Run tests with term + XML coverage report
	$(call log_info,Running coverage...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry run pytest --cov=$(SRC_DIR) --cov-report=term-missing --cov-report=xml
	$(call log_ok,Done)

.PHONY: quality
quality: format lint typecheck coverage ## Run all quality gates (format → lint → types → coverage)

# ──────────────────────────────────────────────────────────────────────────────
### Build & Publish
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: build
build: install-prod ## Build wheel + sdist into dist/
	$(call log_info,Building package...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry build
	$(call log_ok,Artefacts written to dist/)

# Requires in pyproject.toml:
#   [[tool.poetry.source]]
#   name = "azure-artifacts"
#   url  = "https://pkgs.dev.azure.com/<org>/_packaging/<feed>/pypi/simple/"
#
# Auth via pipeline secret variables:
#   POETRY_HTTP_BASIC_AZURE_ARTIFACTS_USERNAME = <anything>
#   POETRY_HTTP_BASIC_AZURE_ARTIFACTS_PASSWORD = <PAT>
.PHONY: publish
publish: build ## Publish to Azure Artifacts (CI only — set CI=true to force locally)
ifeq ($(CI),true)
	$(call log_info,Publishing to Azure Artifacts...)
	@VIRTUAL_ENV=$(CURDIR)/$(VENV) poetry publish --repository azure-artifacts
	$(call log_ok,Package published)
else
	$(call log_warn,Publish skipped — not in CI. Use CI=true make publish to override.)
endif

# ──────────────────────────────────────────────────────────────────────────────
### Cleanup
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: clean-venv
clean-venv: ## Remove venv
	@rm -rf $(VENV)
	$(call log_ok,Removed venv)

.PHONY: clean-build
clean-build: ## Remove dist/, build/, *.egg-info
	@rm -rf build/ $(DIST_DIR) *.egg-info
	$(call log_ok,Build artefacts removed)

.PHONY: clean-pyc
clean-pyc: ## Remove __pycache__ and *.pyc / *.pyo
	@find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	@find . -name '*.py[co]' -delete 2>/dev/null || true
	$(call log_ok,Bytecode cache removed)

.PHONY: clean-test
clean-test: ## Remove .pytest_cache, .coverage, htmlcov, .mypy_cache, .ruff_cache
	@rm -rf .pytest_cache/ .coverage htmlcov/ .mypy_cache/ .ruff_cache/
	$(call log_ok,Test artefacts removed)

.PHONY: clean
clean: clean-venv clean-build clean-pyc clean-test ## Remove all generated artefacts

# ──────────────────────────────────────────────────────────────────────────────
### Utilities
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: demo-logging
demo-logging: ## Demonstrate all log levels
	$(call log_info,Informational — step is about to run)
	$(call log_ok,Success — step completed cleanly)
	$(call log_warn,Warning — non-fatal issue detected)
	$(call log_nok,Failure — step did not complete)

# ──────────────────────────────────────────────────────────────────────────────
### Help
# ──────────────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@grep -E '^(###[ ].+|[a-zA-Z0-9_%/-]+:.*##[^#])' $(firstword $(MAKEFILE_LIST)) \
	  | sed -E \
	      -e 's|^### (.+)|\x1b[1;36m\1\x1b[0m|' \
	      -e 's|^([a-zA-Z0-9_%/-]+):.*## (.+)|  \x1b[32m\1\x1b[0m:\2|' \
	  | awk -F: '{ \
	      if ($$0 !~ /:/) { printf "\n%s\n", $$0 } \
	      else { printf "  %-20s %s\n", $$1, $$2 } \
	    }'
