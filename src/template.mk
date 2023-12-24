MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

.DEFAULT_GOAL := help

.PHONY: help ### show this menu
help:
	@sed -nr '/#{3}/{s/\.PHONY:/--/; s/\ *#{3}/:/; p;}' ${MAKEFILE_LIST}

FORCE:

inspect-%: FORCE
	@echo $($*)

TERM ?=
done := done
fail := fail
info := info

# justify stdout log message using current screen size, right padding is 1
# status messages should be of length 4, e.g. done, fail, info
# padding is set to 6 to account of left and right brackets
define log
if [ ! -z "$(TERM)" ]; then \
	printf "%-$$(($$(tput cols) - 7))s%-7s\n" "$(1)" "[$(2)]" 1>&2;\
	else \
	printf "%-73s%6s \n" "$(1)" "[$(2)]" 1>&2;\
	fi
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

stamp_dir := .stamps

$(stamp_dir):
	@$(call add_gitignore,$@)
	@mkdir -p $@

src_dir := src
tests_dir := tests
dist_dir := dist

$(src_dir) $(tests_dir):
	@mkdir -p $@

.PHONY: clean-stampdir
clean-stampdir:
	@rm -rf $(stamp_dir)
	@$(call del_gitignore,$(stamp_dir))

.PHONY: setup ### install venv and its requirements for package development
setup: install-venv install-requirements

package := mypackage
venv := .venv
pyseed ?= $(shell command -v python3 2> /dev/null)
python := $(venv)/bin/python
pip := $(python) -m pip --disable-pip-version-check

.PHONY: install-venv
install-venv: $(python)

$(python):
	@$(pyseed) -m venv $(venv)
	@$(pip) install --upgrade pip > /dev/null
	@$(pip) install --upgrade build > /dev/null
	@$(call add_gitignore,$(venv))
	@$(call add_gitignore,__pycache__)
	@$(call log,'install venv using seed $(pyseed)',$(done))

.PHONY: clean-venv
clean-venv: clean-requirements
	@rm -rf $(venv)
	@$(call del_gitignore,$(venv))
	@$(call log,'$@',$(done))

requirements := requirements.txt
requirements_stamp := $(stamp_dir)/$(requirements).stamp

.PHONY: install-requirements
install-requirements: $(requirements_stamp)

$(requirements_stamp): $(requirements) $(python) | $(stamp_dir)
	@$(pip) install --upgrade --requirement $< > /dev/null
	@sort --unique --output $<{,}
	@touch $@
	@$(call log,'install project development requirements',$(done))

$(requirements):
	@echo "pytest" >> $@
	@echo "add-trailing-comma" >> $@
	@echo "isort" >> $@
	@echo "pytest-cov" >> $@
	@echo "pytest-mock" >> $@
	@echo "autopep8" >> $@
	@echo "pylint" >> $@
	@echo "pylint-junit" >> $@
	@echo "pynvim" >> $@

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
	@rm -f $(requirements_stamp)
	@$(call log,'uninstall maintenance requirements','$(done)')

.PHONY: clean-requirements
clean-requirements:
	@rm -rf $(requirements_stamp)

.PHONY: venv ### virtual environment help
venv:
	@if [ ! -e $(python) ]; then \
		echo 'No virtual environment found'; \
		echo 'Run: install-venv or setup'; \
		false; \
		fi
	@echo "Active shell: $$0"
	@echo "Command to activate virtual environment:"
	@echo "- bash/zsh: source $(venv)/bin/activate"
	@echo "- fish: source $(venv)/bin/activate.fish"
	@echo "- csh/tcsh: source $(venv)/bin/activate.csh"
	@echo "- PowerShell: $(venv)/bin/Activate.ps1"
	@echo "Exit: deactivate"

.PHONY: development ### setup and install package in editable mode
development: setup install-package

packagerc := pyproject.toml
package_stamp := $(stamp_dir)/$(packagerc).stamp
package_egg := $(package).egg-info
.PHONY: install-package
install-package: $(package_stamp)

$(package_stamp): $(python) $(packagerc) | $(src_dir) $(stamp_dir)
	@$(pip) install --force-reinstall --editable . > /dev/null
	@$(call add_gitignore,$(package_egg))
	@touch $@
	@$(call log,'$(package) installed into venv',$(done))

$(packagerc):
	@echo '[build-system]' >> $@
	@echo 'requires = ["setuptools"]' >> $@
	@echo 'build-backend = "setuptools.build_meta"' >> $@
	@echo '' >> $@
	@echo '[project]' >> $@
	@echo 'name = "$(package)"' >> $@
	@echo 'version = "0.0.1"' >> $@
	@echo 'requires-python = ">=3.7"' >> $@
	@echo 'dependencies = []' >> $@

.PHONY: uninstall-package
uninstall-package:
	@if [ ! -e $(package_stamp) ]; then \
		echo 'Package not installed via current makefile';\
		echo 'It is not safe to uninstall it';\
		false;\
		fi
	@$(pip) uninstall $(package) --yes > /dev/null
	@rm -rf $(package_stamp) $(src_dir)/$(package_egg)
	@$(call del_gitignore,$(package_egg))
	@$(call log,'package uninstalled from venv',$(done))

.PHONY: clean-package
clean-package:
	@rm -rf $(package_stamp) $(src_dir)/$(package_egg)
	@$(call del_gitignore,$(package_egg))

sample_package := $(src_dir)/$(package).py
sample_tests := $(tests_dir)/test_$(package).py
sample_readme := README.md
sample_license := LICENSE

.PHONY: sample ### sample package to demonstrate structure
sample: $(sample_package) $(sample_tests)
sample: $(sample_readme) $(sample_license)

$(sample_package): | $(src_dir)
	@echo "def sample(): return 0" >> $@
	@$(call log,'install sample $@',$(done))

$(sample_tests): | $(tests_dir)
	@echo "import pytest" >> $@
	@echo "from $(package) import sample" >> $@
	@echo "def test_scenario_1(): assert sample() == 0" >> $@
	@echo "def test_scenario_2(): assert not sample() != 0" >> $@
	@$(call log,'install sample $@',$(done))

$(sample_readme):
	@echo '# $(package)' >> $@
	@echo 'Excellent package with much to offer' >> $@
	@echo '## Quickstart' >> $@
	@echo '```' >> $@
	@echo 'git clone URL' >> $@
	@echo 'pyseed=/path/python make development' >> $@
	@echo '```' >> $@
	@$(call log,'install sample $@',$(done))

$(sample_license):
	@echo 'MIT License' >> $@
	@$(call log,'install sample $@',$(done))

.PHONY: clean-sample-code
clean-sample-code:
	@rm -rf $(sample_package) $(sample_tests)
	@$(call log,'clean $(sample_package) and $(sample_tests)',$(done))

.PHONY: clean-sample-aux
clean-sample-aux:
	@rm -rf $(sample_readme) $(sample_license)
	@$(call log,'clean $(sample_readme) and $(sample_license)',$(done))

.PHONY: clean-sample
clean-sample: clean-sample-code clean-sample-aux

module ?= $(package)
args ?= ''
.PHONY: run ### run <module> trough venv, may pass <args>
run: development
ifeq ($(module),$(package))
	@$(python) -m $(module) $(args)
else
	@$(python) $(module) $(args)
endif

.PHONY: check ### test with lint and coverage
check: test lint coverage

.PHONY: test ### doctest and unittest
test: doctest unittest

doctest_module := pytest
doctest_module += --quiet
doctest_module += -rfE
doctest_module += --showlocals
doctest_module += --doctest-modules

ifdef should_junit_report
	doctest_module += --junit-xml=test-results/doctests/results.xml
endif

doctest_target := $(src_dir)
ifneq ($(module),$(package))
	doctest_target := $(module)
endif

.PHONY: doctest ### run doc tests on particular <module> or all under src/
doctest: development
	@$(python) -m $(doctest_module) $(doctest_target) || ([ $$? = 5 ] && exit 0 || exit $$?)
	@$(call log,'doctests',$(done))

unittest_module := pytest
unittest_module += --quiet
unittest_module += -rfE
unittest_module += --showlocals

ifdef should_junit_report
	unittest_module += --junit-xml=test-results/unittests/results.xml
endif

unittest_target := $(tests_dir)

ifneq ($(module),$(package))
	unittest_target := $(module)
endif

.PHONY: unittest ### run unittest on particular <module> or all under tests/
unittest: development
	@$(python) -m $(unittest_module) $(unittest_target)
	@$(call log,'unittests',$(done))

lint_module := pylint --fail-under=5.0

ifdef should_junit_report
	lint_module += --output-format=pylint_junit.JUnitReporter
endif

lint_target := $(src_dir)
ifneq ($(module),$(package))
	lint_target := $(module)
endif

.PHONY: lint ### run lint on particular <module> or all under src/
lint: development
	@$(python) -m $(lint_module) $(lint_target)
	@$(call log,'lint',$(done))

coverage_module := pytest
coverage_module += --cov=$(src_dir)
coverage_module += --cov-branch
coverage_module += --cov-fail-under=50
coverage_module += --doctest-modules

ifdef should_junit_report
	coverage_module += --cov-report=xml:test-results/coverage/report.xml
endif

ifdef should_html_report
	coverage_module += --cov-report=html
endif

coverage_dir := .coverage

.PHONY: coverage ### evaluate test coverage
coverage: development
	@$(python) -m $(coverage_module)
	@$(call add_gitignore,$(coverage_dir))
	@$(call log,'test coverage',$(done))

.PHONY: clean-coverage
clean-coverage:
	@rm -rf $(coverage_dir)
	@$(call del_gitignore,$(coverage_dir))

.PHONY: tests-structure ### make dir for every module under src
tests-structure:
	@if [ -d $(src_dir)/$(package) ]; then\
		find $(src_dir)/$(package) -type f -name '*.py' \
		| grep -vP '__\w+__\.py' \
		| sed -rn "s/$(src_dir)\/$(package)/$(tests_dir)/; s/.py//p" \
		| xargs mkdir --parents;\
		fi

formatter_module_pep8 := autopep8
formatter_module_pep8 += --in-place
formatter_module_pep8 += --aggressive

formatter_module_import_sort := isort
formatter_module_import_sort += --quiet
formatter_module_import_sort += --atomic

formatter_module_add_trailing_comma := add_trailing_comma
formatter_module_add_trailing_comma += --exit-zero-even-if-changed

ifneq ($(module),$(package))
	formatter_module_pep8 += $(module)
	formatter_module_import_sort += $(module)
	formatter_module_add_trailing_comma += $(module)
else
	formatter_module_pep8 += --recursive $(src_dir)/ $(tests_dir)/
	formatter_module_import_sort += $(shell find $(src_dir)/ $(tests_dir)/ -type f -name '*.py')
	formatter_module_add_trailing_comma += $(shell find $(src_dir)/ $(tests_dir)/ -type f -name '*.py') &> /dev/null
endif

.PHONY: format ### autoformat work dir and auto commit; fails if dirty
format:
ifeq ($(module),$(package))
	@[[ -z $$(git status --porcelain) ]] || (echo 'clean the dirty working tree'; false;)
endif
	@$(python) -m $(formatter_module_pep8)
	@$(python) -m $(formatter_module_import_sort)
	@$(python) -m $(formatter_module_add_trailing_comma)
ifeq ($(module),$(package))
	@git add . && git commit -m 'autoformat commit'
endif
	@$(call log,'auto formatting',$(done))

.PHONY: dist
dist: development test
	@$(call add_gitignore,$(dist_dir))
	@$(python) -m build > /dev/null
	@$(call log,'creating distribution package into $(dist_dir)',$(done))

.PHONY: distclean
distclean:
	@$(call del_gitignore,$(dist_dir))
	@rm -rf $(dist_dir)
	@$(call log,'clean up distribution package $(dist_dir)',$(done))

ipython := $(venv)/bin/ipython
.PHONY: run-ipython ### virtual env ipython
run-ipython: $(ipython)
	$< --colors Linux

$(ipython):
	@$(pip) install ipython > /dev/null
	@$(call log,'install ipython into virtual environment',$(done))

jupyter := $(venv)/bin/jupyter
.PHONY: run-jupyter ### virtual env jupyter server
run-jupyter: $(jupyter)
	 $< notebook

$(jupyter): $(python)
	@$(pip) install notebook > /dev/null
	@$(call log,'install jupyter into virtual environment',$(done))

.PHONY: TAGS ### create tags file
TAGS:
	@$(call add_gitignore,tags)
	@ctags --languages=python --recurse
	@$(call log,'creating tags file',$(done))

.PHONY: clean-TAGS
clean-TAGS:
	@rm --force tags
	@$(call del_gitignore,tags)
	@$(call log,'cleaning tags file',$(done))

.PHONY: clean
clean: clean-package clean-venv clean-stampdir clean-sample-code
clean: clean-TAGS distclean clean-coverage
	@rm -rf __pycache__ .pytest_cache
