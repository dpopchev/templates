MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --check-symlink-times

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

# standard status messages to be used for logging;
# length is fixed to 4 charters
TERM ?=
donestr := done
failstr := fail
infostr := info
warnstr := warn

# justify stdout log message using terminal screen size, if available
# otherwise use predefined values
define log
if [ ! -z "$(TERM)" ]; then \
	printf "%-$$(($$(tput cols) - 7))s[%-4s]\n" $(1) $(2);\
	else \
	printf "%-73s[%4s] \n" $(1) $(2);\
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

stamp_suffix := stamp
stamp_dir := .stamps

$(stamp_dir):
	@$(call add_gitignore,$@)
	@mkdir -p $@

.PHONY: clean-stampdir
clean-stampdir:
	@rm -rf $(stamp_dir)
	@$(call del_gitignore,$(stamp_dir))

src_dir := src
tests_dir := tests
workspace_dir := workspace
data_dir := data

$(src_dir) $(tests_dir):
	@mkdir -p $@

$(workspace_dir):
	@mkdir -p $@
	@$(call add_gitignore,$@/)

package := mypackage
venv := .venv
pyseed ?= $(shell command -v python3 2> /dev/null)
python := $(venv)/bin/python
pip := $(python) -m pip --disable-pip-version-check
requirements := requirements.txt
requirements_stamp := $(stamp_dir)/$(requirements).$(stamp_suffix)

.PHONY: venv ### install and setup virtual python environment
venv: $(requirements_stamp)

$(requirements_stamp): $(requirements) $(python) | $(stamp_dir)
	@$(pip) install --upgrade --requirement $< > /dev/null
	@sort --unique --output $<{,}
	@touch $@
	@$(call log,'install venv requirements',$(donestr))

$(python):
	@$(pyseed) -m venv $(venv)
	@$(pip) install --upgrade pip > /dev/null
	@$(pip) install --upgrade build > /dev/null
	@$(call add_gitignore,$(venv))
	@$(call add_gitignore,__pycache__)
	@$(call log,'make venv using $(pyseed)',$(donestr))

$(requirements):
	@echo "pytest" >> $@
	@echo "pytest-cov" >> $@
	@echo "pytest-mock" >> $@
	@echo "pytest-datafiles" >> $@
	@echo "pytest-datadir" >> $@
	@echo "pylint" >> $@
	@echo "pylint-junit" >> $@
	@echo "autopep8" >> $@
	@echo "mypy" >> $@
	@echo "add-trailing-comma" >> $@
	@echo "isort" >> $@
	@echo "pynvim" >> $@

.PHONY: clean-venv ###
clean-venv:
	@rm -rf $(venv) $(requirements_stamp)

packagerc := pyproject.toml
sample_package := $(src_dir)/$(package)
sample_module := $(sample_package)/sample.py
sample_tests := $(tests_dir)/sample
sample_module_test := $(sample_tests)/test_zero_function.py
sample_pytyped_marker := $(sample_package)/py.typed
sample_init := $(sample_package)/__init__.py
sample_readme := README.md
sample_license := LICENSE

.PHONY: sample-project ### template project structure with simple sample
sample-project: $(packagerc)
sample-project: $(sample_module) $(sample_module_test)
sample-project: $(sample_pytyped_marker) $(sample_init)
sample-project: $(sample_init) $(sample_readme) $(sample_license)

$(sample_package) $(sample_tests):
	@mkdir --parents $@

$(sample_module): | $(sample_package)
	@echo "def sample() -> int: return 0" > $@
	@$(call log,'make sample $@',$(donestr))

$(sample_module_test): | $(sample_tests)
	@echo "from $(basename $(notdir $(sample_package))).sample import sample" > $@
	@echo "def test_scenario_1(): assert sample() == 0" >> $@
	@$(call log,'make sample $@',$(donestr))

$(sample_init) $(sample_pytyped_marker): | $(sample_package)
	@touch $@
	@$(call log,'make sample $@',$(donestr))

$(sample_readme):
	@echo '# $(package)' > $@
	@echo 'Elevator pitch.' >> $@
	@echo '## Install' >> $@
	@echo '```' >> $@
	@echo 'git clone --depth 1 <URL>' >> $@
	@echo 'cd $(subst _,-,$(package))' >> $@
	@echo 'make development' >> $@
	@echo 'make check' >> $@
	@echo '```' >> $@
	@echo 'If more context is needed then rename section to `Installation`.' >> $@
	@echo 'Put details into `Requirements` and `Install` subsections.' >> $@
	@echo '## Usage' >> $@
	@echo 'Place examples with expected output.' >> $@
	@echo 'Start with `Setup` subsection for configuration.' >> $@
	@echo 'Break intu sub-...subsections using scenario/feature names.' >> $@
	@echo '## Acknowledgment' >> $@
	@echo '- [makeareadme](https://www.makeareadme.com/)' >> $@
	@echo '## License' >> $@
	@echo '[MIT](LICENSE)' >> $@
	@$(call log,'make sample $@',$(donestr))

$(sample_license):
	@echo 'MIT License' > $@
	@echo '[get the text](https://choosealicense.com/licenses/mit/)' >> $@
	@$(call log,'make sample $@',$(donestr))

.PHONY: clean-sample-code ### remove sample_* related files
clean-sample-code:
	@rm -rf $(sample_module) $(sample_tests)
	@$(call log,'clean $(sample_package) and $(sample_tests)',$(donestr))

package_egg := $(workspace_dir)/$(package).egg-info

.PHONY: development ### make venv and install the package into it
development: venv $(package_egg)

$(package_egg): $(packagerc) $(python) | $(workspace_dir)
	@$(pip) install --force-reinstall --editable . > /dev/null
	@$(call log,'$(package) installed into venv',$(donestr))

$(packagerc):
	@echo '[build-system]' > $@
	@echo 'requires = ["setuptools"]' >> $@
	@echo 'build-backend = "setuptools.build_meta"' >> $@
	@echo '' >> $@
	@echo '[project]' >> $@
	@echo 'name = "$(package)"' >> $@
	@echo 'version = "0.0.1"' >> $@
	@echo 'requires-python = ">=$(shell ($(python) --version 2> /dev/null || echo "3.10") | grep -oP "\d.\d+")"' >> $@
	@echo 'dependencies = []' >> $@
	@echo '[tool.setuptools.package-data]' >> $@
	@echo '"$(package)" = ["py.typed"]' >> $@
	@echo '[tool.setuptools.packages.find]' >> $@
	@echo 'where = ["src"]' >> $@
	@echo '[tool.distutils.egg_info]' >> $@
	@echo 'egg_base = "build"' >> $@
	@$(call log,'make sample $@',$(donestr))

.PHONY: uninstall-package ### uninstall package from venv
uninstall-package:
	@$(pip) uninstall $(package) --yes > /dev/null
	@rm -rf $(package_egg)
	@$(call del_gitignore,$(package_egg))
	@$(call log,'package uninstalled from venv',$(donestr))

args ?= ''
.PHONY: run ### run the package with optional args, e.g. make run args='-h'
run: setup
	@$(python) -m $(package) $(args)

.PHONY: check ### test, lint and coverage
check: test lint coverage

.PHONY: test ### doctest, unittest and mypy
test: doctest unittest mypy

doctest_module := pytest
doctest_module += --quiet
doctest_module += -rfE
doctest_module += --showlocals
doctest_module += --doctest-modules
doctest_module += --doctest-continue-on-failure

ifdef should_generate_report
	doctest_module += --junit-xml=test-results/doctests/results.xml
endif

.PHONY: doctest ### run doctests
doctest: development
	@$(python) -m $(doctest_module) $(src_dir)/$(package) || ([ $$? = 5 ] && exit 0 || exit $$?)
	@$(call log,'doctests',$(donestr))

unittest_module := pytest
unittest_module += --quiet
unittest_module += -rfE
unittest_module += --showlocals

ifdef should_generate_report
	unittest_module += --junit-xml=test-results/unittests/results.xml
endif

.PHONY: unittest ### run unittest
unittest: development
	@$(python) -m $(unittest_module)
	@$(call log,'unittests',$(donestr))

mypy_module := mypy --pretty --strict

ifdef should_generate_report
	mypy_module += --junit-xml=test-results/mypy/results.xml
endif

.PHONY: mypy ### run mypy
mypy: development
	@$(python) -m $(mypy_module) $(src_dir)/$(package)
	@$(call log,'mypy',$(donestr))

lint_module := pylint --fail-under=5.0

ifdef should_generate_report
	lint_module += --output-format=pylint_junit.JUnitReporter
endif

.PHONY: lint ### run lint
lint: development
	@$(python) -m $(lint_module) $(src_dir)/$(package)
	@$(call log,'lint',$(donestr))

coverage_module := pytest
coverage_module += --cov=$(package)
coverage_module += --cov-branch
coverage_module += --cov-fail-under=50

ifdef should_generate_report
	coverage_module += --cov-report=xml:test-results/coverage/report.xml
endif

ifdef should_generate_html_report
	coverage_module += --cov-report=html
endif

coverage_dir := .coverage

.PHONY: coverage ### evaluate test coverage
coverage: development
	@$(call add_gitignore,$(coverage_dir))
	@$(python) -m $(coverage_module)
	@$(call log,'test coverage',$(donestr))

formatter_module_pep8 := autopep8
formatter_module_pep8 += --in-place
formatter_module_pep8 += --aggressive

formatter_module_import_sort := isort
formatter_module_import_sort += --quiet
formatter_module_import_sort += --atomic

formatter_module_add_trailing_comma := add_trailing_comma
formatter_module_add_trailing_comma += --exit-zero-even-if-changed

pyfiles:=$(shell find $(src_dir)/ $(tests_dir)/ -type f -name '*.py' 2> /dev/null)
formatter_module_pep8 += --recursive $(src_dir)/ $(tests_dir)/
formatter_module_import_sort += $(pyfiles)
formatter_module_add_trailing_comma += $(pyfiles) &> /dev/null

.PHONY: format ### autoformat work dir and commit; fails if dirty
format:
	@[[ -z $$(git status --porcelain) ]] || (echo 'clean the dirty working tree'; false;)
	@$(python) -m $(formatter_module_pep8)
	@$(python) -m $(formatter_module_import_sort)
	@$(python) -m $(formatter_module_add_trailing_comma)
	@git add . && git commit -m 'style: make format codebase'
	@$(call log,'auto formatting',$(donestr))

dist_dir := $(workspace_dir)/dist

.PHONY: dist ### create distribution files
dist: development test
	@$(call add_gitignore,$(dist_dir))
	@$(python) -m build --outdir $(dist_dir) > /dev/null
	@$(call log,'creating distribution package into $(dist_dir)',$(donestr))

.PHONY: distclean ###
distclean:
	@$(call del_gitignore,$(dist_dir))
	@rm -rf $(dist_dir)
	@$(call log,'clean up distribution package $(dist_dir)',$(donestr))

.PHONY: run-unittest-daemon ### rerun unittest on change of any package module
run-unittest-daemon: development
	find $(src_dir)/$(package) -name '*.py' | entr make unittest

ipython := $(venv)/bin/ipython
.PHONY: run-ipython ### ipython in venv
run-ipython: $(ipython)
	$< --colors Linux

$(ipython):
	@$(pip) install ipython > /dev/null
	@$(call log,'install ipython into virtual environment',$(donestr))

jupyter := $(venv)/bin/jupyter
jupyter_extensions := jupyterlab-vim
jupyter_extensions += jupyterlab-lsp
jupyter_extensions += jupytext
notebooks_dir := notebooks

$(notebooks_dir):
	@mkdir -p $@

.PHONY: run-jupyter ### jupyter lab in venv
run-jupyter: $(jupyter) | $(notebooks_dir)
	$< lab $(notebooks_dir)

$(jupyter): $(python)
	@$(call add_gitignore,.ipynb_checkpoints)
	@$(pip) install jupyterlab $(jupyter_extensions) > /dev/null
	@$(call log,'install jupyter into virtual environment',$(donestr))

.PHONY: jupyter-lsp-servers ### setup lsp for jupyter trough npm
jupyter-lsp-servers:
	@npm install --save-dev pyright

tensorboard := $(venv)/bin/tensorboard
tensorboard_logs := $(workspace_dir)/tensorboard

.PHONY: run-tensorboard ### tensorboard in venv
run-tensorboard: $(tensorboard) | $(tensorboard_logs)
	$< --logdir $(tensorboard_logs)

$(tensorboard_logs):
	@$(call add_gitignore,"$@/")
	mkdir -p $@

$(tensorboard): $(python)
	@$(pip) install tensorboard > /dev/null
	@$(call log,'install tensorboard into virtual environment',$(donestr))

.PHONY: clean-cache ###
clean-cache:
	@find . -name ".ipynb_checkpoints" -type d -exec rm -fr {} +
	@find . -name "*.pyc" -type f -exec rm -fr {} +
	@find . -name "__pycache__" -type d -exec rm -fr {} +
	@rm -rf .mypy_cache .pytest_cache .coverage
