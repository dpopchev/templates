MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

.DEFAULT_GOAL := help

.PHONY: help ### show this menu
help:
	@sed -nr '/#{3}/{s/\.PHONY:/--/; s/\ *#{3}/:/; p;}' ${MAKEFILE_LIST}

# handy definitions...
comma := ,
empty :=
space := $(empty) $(empty)

# ...to achieve list joining
foo := a b c
bar := $(subst $(space),$(comma),$(foo))

# ...use comma as argument
rcs_archive := foo.c,v
rcs_srcs := $(patsubst %$(comma)v,%,$(rcs_archive))

# optional environment variable
ENVVAR ?=

# globally required environment variable
ifdef $(HOME)
	$(error HOME not set)
endif

# environment variable required by target
echo_home:
	if [ -z $(HOME) ]; then echo 'HOME not defined'; false; fi
	echo $(HOME)

FORCE:

inspect-%: FORCE
	@echo $($*)

define add_gitignore
	grep --quiet --line-regexp --fixed-strings $(1) .gitignore 2> /dev/null \
	|| echo $(1) >> .gitignore
	sort -o .gitignore{,}
endef

define del_gitignore
	sed --in-place '\,$*,d' .gitignore
	sort -o .gitignore{,}
endef

add-gitignore-%: FORCE
	@$(call add_gitignore,$*)

add-gitignore-/%: FORCE
	@$(call add_gitignore,$*)

del-gitignore-%: FORCE
	@$(call del_gitignore,$*)

del-gitignore-/%: FORCE
	@$(call del_gitignore,$*)

venv := $(shell echo $${VIRTUAL_ENV-.venv})
VIRTUAL_ENV ?= ''
pyseed ?= $(shell command -v python3 2> /dev/null)
python := $(venv)/bin/python
pip := $(python) -m pip

define is_venv_inactive
	if [[ ! -z $(VIRTUAL_ENV) ]]; then \
		echo 'Python virtual environment ACTIVE'; \
		echo 'Run: deactivate'; \
		exit 2; \
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

define log
	printf "%-60s %20s \n" $(1) $(2)
endef

stamp_dir := .stamps

$(stamp_dir):
	mkdir --parents $@

.PHONY: stampdir
stampdir: add-gitignore-$(stamp_dir) | $(stamp_dir)

venv_stamp := $(stamp_dir)/venv.stamp
$(venv_stamp): | stampdir add-gitignore-$(venv)
	@$(call is_venv_inactive)
	@$(call has_python_seed)
	$(pyseed) -m venv $(venv)
	$(pip) install --upgrade pip > /dev/null
	$(pip) install --upgrade build > /dev/null
	@touch $@

.PHONY: setup-venv
setup-venv: $(venv_stamp)
	@$(call log,'virtual env setup', '[done]')

.PHONY: clean-venv
clean-venv: add-gitignore-$(venv)
	rm --force --recursive $(venv_stamp) $(venv)

.PHONY: venv
venv: setup-venv
	@echo "Active shell: $$0"
	@echo "Command to activate virtual environment:"
	@echo "- bash/zsh: source $(venv)/bin/activate"
	@echo "- fish: source $(venv)/bin/activate.fish"
	@echo "- csh/tcsh: source $(venv)/bin/activate.csh"
	@echo "- PowerShell: $(venv)/bin/Activate.ps1"
	@echo "Exit: deactivate"

requirements := requirements.txt
$(requirements):
	@echo "pytest" >> $@
	@echo "pytest-mock" >> $@
	@echo "pytest-cov" >> $@
	@echo "pytest-datafiles" >> $@
	@echo "pylint" >> $@
	@echo "pylint-junit" >> $@
	@echo "autopep8" >> $@
	@echo "pynvim" >> $@

requirements_stamp := $(stamp_dir)/$(requirements).stamp
$(requirements_stamp): $(requirements) $(venv_stamp)
	$(pip) install --upgrade --requirement $< > /dev/null
	@sort -o $(requirements){,}
	@touch $@

.PHONY: setup-requirements
setup-requirements: setup-venv $(requirements_stamp)
	@$(call log,'requirements setup', '[done]')

.PHONY: setup ### setup virtual environment for project and its requirements
setup: setup-venv setup-requirements
	@echo 'setup venv'
