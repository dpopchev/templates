MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

package := template
pyseed ?= $(shell command -v python3 2> /dev/null)
venv := $(shell echo $${VIRTUAL_ENV-.venv})
VIRTUAL_ENV ?= ''
python := $(venv)/bin/python
pip := $(python) -m pip
FILE ?=
ARGS ?=
SHOULD_JUNIT_REPORT ?=

.DEFAULT_GOAL := help

.PHONY: help ### show this menu
help:
	@sed -nr '/#{3}/{s/\.PHONY:/--/; s/\ *#{3}/:/; p;}' ${MAKEFILE_LIST}

FORCE:

inspect-%: FORCE
	@echo $($*)

define log
	printf "%-50s %30s \n" $(1) $(2)
endef

define add_gitignore
	echo $(1) >> .gitignore;
	sort --unique --output .gitignore{,};
endef

define del_gitignore
	if [ -e .gitignore ]; then\
		sed --in-place '\,$(1),d' .gitignore;\
		sort --unique --output .gitignore{,};\
	fi
endef

define has_python_seed
	if [[ -z $(pyseed) ]]; then \
		echo 'No python seed found, possible resolutions:'; \
		echo '-- pass inline, e.g. pyseed=/path/python make <goal>';\
		echo '-- overwrite <pyseed> variable in Makefile';\
		exit 2; \
	fi
endef

define is_venv_inactive
	@if [[ ! -z $(VIRTUAL_ENV) ]]; then \
		echo 'Python virtual environment ACTIVE'; \
		echo 'Run: deactivate'; \
		exit 2; \
	fi
endef

define is_venv_present
	@if [[ ! -e $(python) ]]; then \
		echo 'No virtual environment found'; \
		echo 'Run: make install-venv'; \
		exit 2; \
	fi
endef

stamp_dir := .stamps

$(stamp_dir):
	@$(call add_gitignore,$@)
	@mkdir --parents $@
	@$(call log,'make stamps home','[done]')

.PHONY: clean-stampdir
clean-stampdir:
	@rm --force --recursive $(stamp_dir)
	@$(call del_gitignore,$(stamp_dir))
	@$(call log,'remove stamps home','[done]')

venv_stamp := $(stamp_dir)/venv.stamp
$(venv_stamp): | $(stamp_dir)
	@$(call has_python_seed)
	@$(call is_venv_inactive)
	@$(pyseed) -m venv $(venv)
	@$(pip) install --upgrade pip > /dev/null
	@$(pip) install --upgrade build > /dev/null
	@$(call add_gitignore,$(venv))
	@touch $@
	@$(call log,'install virtual environment','[done]')

.PHONY: install-venv ###
install-venv: $(venv_stamp)

.PHONY: clean-venv
clean-venv:
	@$(call is_venv_inactive)
	@rm --force --recursive $(venv) $(venv_stamp)
	@$(call del_gitignore,$(venv))
	@$(call log,'remove virtual environment','[done]')

.PHONY: venv ### virtual environment control info
venv:
	@$(call is_venv_present)
	@echo "Active shell: $$0"
	@echo "Command to activate virtual environment:"
	@echo "- bash/zsh: source $(venv)/bin/activate"
	@echo "- fish: source $(venv)/bin/activate.fish"
	@echo "- csh/tcsh: source $(venv)/bin/activate.csh"
	@echo "- PowerShell: $(venv)/bin/Activate.ps1"
	@echo "Exit: deactivate"

.PHONY: install-requirements
install-requirements:
	@$(call log,'install maintenance requirements','[done]')

.PHONY: clean
clean: clean-venv clean-stampdir
