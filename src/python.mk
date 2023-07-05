MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

package := my_pypackage
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
	printf "%-60s %20s \n" $(1) $(2)
endef

define add_gitignore
	echo $(1) >> .gitignore;
	sort --unique --output .gitignore{,};
endef

define del_gitignore
	if [ -e .gitignore ]; then \
		sed --in-place '\,$(1),d' .gitignore;\
		sort --unique --output .gitignore{,};\
	fi
endef

define has_python_seed
	if [ -z $(pyseed) ]; then \
		echo 'No python seed found, possible resolutions:'; \
		echo '-- pass inline, e.g. pyseed=/path/python make <goal>';\
		echo '-- overwrite <pyseed> variable in Makefile';\
		exit 2; \
	fi
endef

define is_venv_inactive
	if [ ! -z $(VIRTUAL_ENV) ]; then \
		echo 'Python virtual environment ACTIVE'; \
		echo 'Run: deactivate'; \
		exit 2; \
	fi
endef

define is_venv_present
	if [ ! -e $(python) ]; then \
		echo 'No virtual environment found'; \
		echo 'Run: make install-venv'; \
		exit 2; \
	fi
endef

stamp_dir := .stamps
src_dir := src
test_dir := tests

$(stamp_dir):
	@$(call add_gitignore,$@)
	@mkdir --parents $@
	@$(call log,'make stamps home','[done]')

$(src_dir) $(test_dir):
	@mkdir --parents $@

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

.PHONY: install-venv ### counterpart: clean
install-venv: $(venv_stamp)

.PHONY: clean-venv
clean-venv:
	@$(call is_venv_inactive)
	@rm --force --recursive $(venv) $(venv_stamp)
	@$(call del_gitignore,$(venv))
	@$(call log,'remove virtual environment','[done]')

.PHONY: venv ### virtual environment help
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

requirements_stamp := $(stamp_dir)/requirements.stamp
$(requirements_stamp): $(requirements) | $(stamp_dir)
	@$(call is_venv_present)
	@$(pip) install --upgrade --requirement $< > /dev/null
	@touch $@
	@$(call log,'install project maintenance requirements','[done]')

.PHONY: install-requirements ### counterparts: uninstall, clean
install-requirements: $(requirements_stamp)

.PHONY: uninstall-requirements
uninstall-requirements:
	@if [ ! -e $(requirements_stamp) ]; then\
		echo 'Misisng installation stamp';\
		echo 'run make install-requirements';\
		false;\
	fi
	@if [ -e $(requirements) ]; then\
		$(pip) uninstall --requirement $(requirements) --yes > /dev/null;\
	fi
	@rm --force $(requirements_stamp)
	@$(call log,'uninstall maintenance requirements','[done]')

.PHONY: clean-requirements
clean-requirements:
	@rm --force $(requirements) $(requirements_stamp)
	@$(call log,'remove maintenance requirements','[done]')

.PHONY: setup ### install venv and project requirements
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
	@echo '```' >> $@
	@echo 'git clone ${url}' >> $@
	@echo 'pyseed=/path/python make development' >> $@
	@echo '```' >> $@

LICENSE:
	@echo 'MIT License' >> $@

pyproject_stamp := $(stamp_dir)/pyproject.stamp
$(pyproject_stamp): $(pyprojectrc) | $(stamp_dir)
	@touch $@
	@$(call log,'setup missing python packaging files','[done]')

.PHONY: setup-pyproject ### add missing python packaging files, counterpart: clean
setup-pyproject: $(pyproject_stamp)

.PHONY: clean-pyproject
clean-pyproject:
	@rm --force $(pyprojectrc) $(pyproject_stamp)
	@$(call log,'clean ALL python packaging files','[done]')

sample_package := $(src_dir)/$(package).py
$(sample_package): | $(src_dir)
	@echo "def sample(): return 0" >> $@
	@$(call log,'install sample python package','[done]')

sample_tests := $(test_dir)/test_$(package).py
$(sample_tests): | $(test_dir)
	@echo "import pytest" >> $@
	@echo "from $(package) import sample" >> $@
	@echo "def test_scenario_1(): assert sample() == 0" >> $@
	@echo "def test_scenario_2(): assert not sample() != 0" >> $@
	@$(call log,'install tests for sample python package','[done]')

.PHONY: install-sample ### sample python project, counterpart: clean
install-sample: $(sample_package) $(sample_tests)

.PHONY: clean-sample
clean-sample:
	@rm --force $(sample_package) $(sample_tests)
	@$(call log,'remove sample package and its tests','[done]')

package_egg := $(package).egg-info
package_stamp := $(stamp_dir)/package.stamp
$(package_stamp): $(pyproject_stamp) $(venv_stamp) | $(stamp_dir)
	@$(pip) install --editable . > /dev/null
	@$(call add_gitignore,$(package_egg))
	@$(call add_gitignore,__pycache__)
	@touch $@
	@$(call log,'install package into virtual environment as editable','[done]')

.PHONY: install-package ### install project package into venv, counterpart: uninstall, clean
install-package: $(package_stamp)

.PHONY: uninstall-package
uninstall-package:
	@$(pip) uninstall $(package) --yes > /dev/null
	@rm $(package_stamp)
	@$(call log,'uninstall package from virtual environment','[done]')

.PHONY: clean-package
clean-package:
	@rm --force --recursive $(shell find . -type d -name "$(package_egg)") $(package_stamp)
	@$(call del_gitignore,$(package_egg))
	@$(call log,'clean package auxiliaries; make sure its was uninstalled','[done]')

.PHONY: development ### setup virtual environment and install package
development: setup install-package

.PHONY: run ### run particular <FILE>, optionally pass some <ARGS>
run: development
	$(python) $(FILE) $(ARGS)

doctest_ignore := $(shell find -maxdepth 1 -mindepth 1 -type d -not -name $(src_dir))
doctest_module := pytest
doctest_module += --quiet
doctest_module += -rfE
doctest_module += --showlocals
doctest_module += $(addprefix --ignore=,$(doctest_ignore))
doctest_module += --doctest-modules

ifdef SHOULD_JUNIT_REPORT
doctest_module += --junit-xml=test-results/doctests/results.xml
endif

.PHONY: doctest ### run doc tests on particular <FILE> or all under $(src-dit)
doctest: development
	@$(python) -m $(doctest_module) $(FILE) || true
	@$(call log,'doctests','[done]')

unittest_ignore := $(shell find -maxdepth 1 -mindepth 1 -type d -not -name $(test_dir))
unittest_module := pytest
unittest_module += --quiet
unittest_module += -rfE
unittest_module += --showlocals
unittest_module += $(addprefix --ignore=,$(unittest_ignore))

ifdef SHOULD_JUNIT_REPORT
unittest_module += --junit-xml=test-results/unittests/results.xml
endif

.PHONY: unittest ### run unittest on particular <FILE> or all under $(test-dir)
unittest: development
	@$(python) -m $(unittest_module) $(FILE)
	@$(call log,'unittest','[done]')

.PHONY: test ### doctest and unittest
test: doctest unittest

list_module := pylint
list_module += --fail-under=7.5

ifdef FILE
lint_runner := $(python) -m $(list_module) $(FILE)
else
lint_runner := $(python) -m $(list_module) $(src_dir)/
endif

ifdef SHOULD_JUNIT_REPORT
lint_runner += --output-format=pylint_junit.JUnitReporter
lint_runner += > test-results/lint/results.xml
endif

.PHONY: lint ### run lintter on <FILE> or all under $(src_dir);
lint: development
ifdef SHOULD_JUNIT_REPORT
	mkdir --parents test-results/lint/
endif
	$(lint_runner)
	@$(call log,'linter','[done]')

coverage_module := pytest
coverage_module += --cov=$(src_dir)
coverage_module += --cov-branch
coverage_module += --cov-fail-under=75
coverage_module += --doctest-modules

ifdef SHOULD_JUNIT_REPORT
coverage_module += --cov-report=xml:test-results/coverage/report.xml
endif

ifdef SHOULD_HTML_REPORT
coverage_module += --cov-report=html
endif

coverage-runner := $(python) -m $(coverage_module)

.PHONY: coverage ### evaluate test coverage
coverage: development
	@$(coverage-runner)
	@$(call add_gitignore,.coverage)
	@$(call log,'test coverage','[done]')

.PHONY: check ### test with lint and coverage
check: test lint coverage

.PHONY: clean
clean: clean-package clean-venv clean-stampdir
