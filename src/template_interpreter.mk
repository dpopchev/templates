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
done := [done]
fail := [fail]
info := [info]

# justify stdout log message using current screen size, right padding is 1
# status messages should be of length 4, e.g. done, fail, info
# padding is set to 6 to account of left and right brackets
define log
if [ ! -z "$(TERM)" ]; then \
	printf "%-$$(($$(tput cols) - 7))s%-7s\n" $(1) $(2);\
	else \
	printf "%-73s%6s \n" $(1) $(2);\
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
venv_seed ?=
venv_intrpr := interpret
venv_mgr := package_manager

.PHONY: install-venv
install-venv: $(venv_intrpr)

$(venv_intrpr):
	@echo 'Recipe to create project dedicated namespace'
	@echo 'aka virtual environment'
	@$(call add_gitignore,$(venv))
	@$(call log,'install venv using seed $(venv_seed)',$(done))

.PHONY: clean-venv
clean-venv: clean-requirements
	@echo 'Recipie to remove local namespace'
	@$(call del_gitignore,$(venv))
	@$(call log,'$@',$(done))

requirements := requirements
requirements_stamp := $(stamp_dir)/$(requirements).stamp

.PHONY: install-requirements
install-requirements: $(requirements_stamp)

$(requirements_stamp): $(requirements) $(venv_intrpr) | $(stamp_dir)
	@echo 'Recipe to install development package requirements'
	@sort --unique --output $<{,}
	@touch $@
	@$(call log,'install project development requirements',$(done))

$(requirements):
	@echo 'Common requirements list'

.PHONY: uninstall-requirements
uninstall-requirements:
	@if [ ! -e $(requirements_stamp) ]; then\
		echo 'Misisng installation stamp';\
		echo 'run make install-requirements';\
		false;\
	fi
	@if [ -e $(requirements) ]; then\
		echo 'Recipe for uninstalling requirements'\
	fi
	@rm -f $(requirements_stamp)
	@$(call log,'uninstall maintenance requirements','$(done)')

.PHONY: clean-requirements
clean-requirements:
	@rm -rf $(requirements_stamp)

.PHONY: venv ### virtual environment help
venv:
	@if [ ! -e $(venv_intrpr) ]; then \
		echo 'No virtual environment found'; \
		echo 'Run: install-venv or setup'; \
		false; \
	fi
	@echo 'Help recipe on virtual environment, e.g. activation, deactivation'

.PHONY: development ### setup and install package in editable mode
development: setup install-package

packagerc := packagerc
package_stamp := $(stamp_dir)/$(packagerc).stamp
.PHONY: install-package
install-package: $(package_stamp)

$(package_stamp): $(venv_intrpr) $(packagerc) | $(src_dir) $(stamp_dir)
	@echo 'Recipe to install package named $(package) into the local namespace'
	@touch $@
	@$(call log,'$(package) installed into venv',$(done))

$(packagerc):
	@echo 'Recipe common package meta data'

.PHONY: uninstall-package
uninstall-package:
	@if [ ! -e $(package_stamp) ]; then \
		echo 'Package not installed via current makefile';\
		echo 'It is not safe to uninstall it';\
		false;\
	fi
	@echo 'Recipe to uninstall package from local namespace'
	@rm -rf $(package_stamp)
	@$(call log,'package uninstalled from venv',$(done))

.PHONY: clean-package
clean-package:
	@rm -rf $(package_stamp)

sample_package := $(src_dir)/sample_$(package)
sample_tests := $(tests_dir)/test_sample_$(package)
sample_readme := README.md
sample_license := LICENSE

.PHONY: sample ### sample package to demonstrate structure
sample: $(sample_package) $(sample_tests)
sample: $(sample_readme) $(sample_license)

$(sample_package): | $(src_dir)
	@echo 'Sample package implementation'
	@$(call log,'install sample $@',$(done))

$(sample_tests): | $(tests_dir)
	@echo 'Sample unittest'
	@$(call log,'install sample $@',$(done))

$(sample_readme):
	@echo '# $(package))' >> $@
	@echo 'Elevator pitch.' >> $@
	@echo '## Install' >> $@
	@echo '```' >> $@
	@echo 'git clone --depth 1 <URL>' >> $@
	@echo 'cd $(subst _,-,$(package))' >> $@
	@echo 'make check' >> $@
	@echo '```' >> $@
	@echo 'If more context is needed then rename section to `Installation`.' >> $@
	@echo 'Put details into `Requirements` and `Install` subsections.' >> $@
	@echo '## Usage' >> $@
	@echo 'Place examples with expected output.' >> $@
	@echo 'Start with `Setup` subsection for configuration.' >> $@
	@echo 'Break intu sub-...subsections using scenario/feature names.' >> $@
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
	@echo 'run package  within venv'
else
	@echo 'run any module within venv'
endif

.PHONY: check ### test with lint and coverage
check: test lint coverage

.PHONY: test ### doctest and unittest
test: doctest unittest

doctest_module :=

ifdef should_generate_report
	doctest_module += report_flag
endif

doctest_target := $(src_dir)
ifneq ($(module),$(package))
	doctest_target := $(module)
endif

.PHONY: doctest ### run doc tests on particular <module> or all under src/
doctest: development
	@echo 'Run documentation test found in target $(doctest_targert)'
	@$(call log,'doctests',$(done))

unittest_module :=

ifdef should_generate_report
	unittest_module += report_flag
endif

unittest_target := $(tests_dir)

ifneq ($(module),$(package))
	unittest_target := $(module)
endif

.PHONY: unittest ### run unittest on particular <module> or all under tests/
unittest: development
	@echo 'Run unittest found in target $(unittest_target)'
	@$(call log,'unittests',$(done))

lint_module :=

ifdef should_generate_report
	lint_module += report_flag
endif

lint_target := $(src_dir)
ifneq ($(module),$(package))
	lint_target := $(module)
endif

.PHONY: lint ### run lint on particular <module> or all under src/
lint: development
	@echo 'Run lint on $(lint_target)'
	@$(call log,'lint',$(done))

coverage_module :=

ifdef should_generate_report
	coverage_module += report_flag
endif

.PHONY: coverage ### evaluate test coverage
coverage: development
	@echo 'Evaluate test coverage'
	@$(call log,'test coverage',$(done))

.PHONY: tests-structure ### make dir for every module under src
tests-structure:
	@echo 'Recipe to mirror $(src_dir) structure into $(tests_dir)'

.PHONY: format ### autoformat work dir and auto commit; fails if dirty
format:
	@echo 'Recipe to auto format the code'

.PHONY: dist
dist: development test
	@echo 'Make distribution package'
	@$(call add_gitignore,$(dist_dir))
	@$(call log,'creating distribution package into $(dist_dir)',$(done))

.PHONY: distclean
distclean:
	@$(call del_gitignore,$(dist_dir))
	@rm -rf $(dist_dir)
	@$(call log,'clean up distribution package $(dist_dir)',$(done))

.PHONY: TAGS ### create tags file
TAGS:
	@echo 'Make tags file'
	@$(call add_gitignore,tags)
	@$(call log,'creating tags file',$(done))

.PHONY: clean-TAGS
clean-TAGS:
	@rm --force tags
	@$(call del_gitignore,tags)
	@$(call log,'cleaning tags file',$(done))

.PHONY: clean
clean: clean-package clean-venv clean-stampdir clean-sample-code
clean: clean-TAGS distclean clean-coverage
