MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

.DEFAULT_GOAL := help

.PHONY: help ### show this menu
help:
	@sed -nr '/#{3}/{s/\.PHONY:/--/; s/\ *#{3}/:/; p;}' ${MAKEFILE_LIST}

package := template
venv := $(shell echo $${VIRTUAL_ENV-.venv})
VIRTUAL_ENV ?= ''
pyseed ?= $(shell command -v python3 2> /dev/null)
python := $(venv)/bin/python
pip := $(python) -m pip

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

define is_venv_present
	if [[ ! -e $(python) ]]; then \
		echo 'No virtual environment found'; \
		echo 'Run: make install-venv'; \
		exit 2; \
	fi
endef

define log
	printf "%-50s %30s \n" $(1) $(2)
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

.PHONY: install-venv ###
install-venv: $(venv_stamp)
	@$(call log,'install virtual env','[done]')

.PHONY: clean-venv
clean-venv: del-gitignore-$(venv)
	rm --force --recursive $(venv_stamp) $(venv)

.PHONY: venv
venv:
	@$(call is_venv_present)
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

.PHONY: install-requirements ###
install-requirements: $(requirements_stamp) $(venv_stamp)
	@$(call log,'install requirements','[done]')

.PHONY: uninstall-requirements
uninstall-requirements:
	@$(call is_venv_present)
	[[ ! -e $(requirements) ]] || $(pip) uninstall --requirement $(requirements) --yes
	@rm --force $(requirements_stamp)

.PHONY: clean-requirements
clean-requirements:
	$(pip) uninstall --requirement $(requirements) --yes > /dev/null 2>&1 || true
	rm --force $(requirements) $(requirements_stamp)

.PHONY: setup ### install-venv and install-requirements
setup: install-venv install-requirements

pyprojectrc := pyproject.toml README.md LICENSE
pyproject.toml:
	@echo '[build-system]' >> $@
	@echo 'requires = ["setuptools"]' >> $@
	@echo 'build-backend = "setuptools.build_meta"' >> $@
	@echo '' >> $@
	@echo '[project]' >> $@
	@echo 'name = "$(package)"' >> $@
	@echo 'version = "0.0.1"' >> $@
	@echo 'requires-python = ">=3.7"' >> $@
	@echo 'dependencies = []' >> $@

README.md:
	@echo '# $(package)' >> $@
	@echo 'Excellent package with much to offer' >> $@
	@echo '## Quickstart' >> $@
	@echo 'clone and `pyseed=/path/python make development`' >> $@

LICENSE:
	@echo 'MIT License' >> $@

pyproject_stamp := $(stamp_dir)/pyproject.stamp
$(pyproject_stamp): $(pyprojectrc) | $(stamp_dir)
	@touch $@

.PHONY: setup-pyproject ### pyproject.toml, README, LICENSE
setup-pyproject: $(pyproject_stamp)
	@$(call log,'setup python project structure','[done]')

.PHONY: clean-pyproject
clean-pyproject:
	rm --force $(pyprojectrc) $(pyproject_stamp)

.PHONY: clean
clean: clean-venv
