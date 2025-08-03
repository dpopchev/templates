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

# logging uses it to evaluate terminal width if present; else fullbacks to 80
TERM ?=

# logging status messages with fixed length of 4
donestr := done
failstr := fail
infostr := info
warnstr := warn

# Logging function: [STATUS] Message (truncated to fit terminal width)
define log
	if [ ! -z "$(TERM)" ]; then \
		max_msg_width=$$(($$(tput cols) - 6 - 10)); \
		status="[$(2)]"; \
		msg="$(1)"; \
		if [[ "$${#msg}" -gt $$max_msg_width ]]; then \
			msg="$$(echo "$$msg" | cut -c1-$$max_msg_width)..."; \
		fi; \
		printf "%s %s\n" "$$status" "$$msg"; \
	else \
		max_msg_width=$$((40 - 6 - 10)); \
		status="[$(2)]"; \
		msg="$(1)"; \
		if [[ "$${#msg}" -gt $$max_msg_width ]]; then \
			msg="$$(echo "$$msg" | cut -c1-$$max_msg_width)..."; \
		fi; \
		printf "%s %s\n" "$$status" "$$msg"; \
	fi
endef

# add line and preserve uniqueness of the file,
# useful for gitignore and a-like
define add_line
	echo $(1) >> $(2);\
	sort --unique --output $(2){,}
endef

# del line and preserve uniqueness of the file,
# useful for gitignore and a-like
define del_line
	if [[ -e $(2) ]]; then \
		sed --in-place '\,$(1),d' $(2);\
		sort --unique --output $(2){,};\
	fi
endef

venv := .venv
pyseed ?= $(shell command -v python3 2> /dev/null)
python := $(venv)/bin/python
pip := $(venv)/bin/pip
requirements := requirements
gitignore := .gitignore

$(requirements):
	@mkdir -p $@

.PHONY: venv ### build local python environment
venv: $(python) requirements-pip

requirements-pip := $(requirements)/pip.txt

.PHONY: requirements-pip ### install required pinned pip
requirements-pip: $(python)
	@$(pip) install -r $(requirements-pip)
	@$(call log,required pip installed,$(donestr))

$(python): | $(requirements)
	@$(pyseed) -m venv $(venv)
	@$(pip) install --upgrade pip > /dev/null
	@$(pip) freeze --all | grep 'pip==' > $(requirements-pip)
	@$(call log,pip version requirment set,$(donestr))
	@$(pip) install --upgrade build > /dev/null
	@$(call add_line,$(venv),$(gitignore))
	@$(call add_line,__pycache__,$(gitignore))
	@$(call log,venv created using $(pyseed),$(donestr))

.PHONY: clean-venv ###
clean-venv:
	@rm -rf $(venv) $(requirements-pip)

source_code := src
tests := tests
workspace := workspace

$(source_code) $(tests):
	@mkdir -p $@

$(workspace):
	@mkdir -p $@
	@$(call add_line,$@,$(gitignore))

packagerc := pyproject.toml
license := LICENSE
readme := README.md

.PHONY: init ### template project structure
init: $(packagerc) $(readme) $(license)| $(source_code) $(tests) $(workspace)
	@git init > /dev/null
	@$(call log,git initialized,$(donestr))
	@$(call log,rename <PACKAGENAME> placeholder,$(warnstr))
	@$(call log,set local git author with `git config user.{<name>,<email>}...,$(warnstr))

$(packagerc):
	@echo '[build-system]' > $@
	@echo 'requires = ["setuptools"]' >> $@
	@echo 'build-backend = "setuptools.build_meta"' >> $@
	@echo '' >> $@
	@echo '[project]' >> $@
	@echo 'name = "<PACKAGENAME>"' >> $@
	@echo 'version = "0.0.1"' >> $@
	@echo 'requires-python = ">=$(shell ($(python) --version 2> /dev/null || echo "3.10") | grep -oP "\d.\d+")"' >> $@
	@echo 'dependencies = []' >> $@
	@echo '[tool.setuptools.package-data]' >> $@
	@echo '"<PACKAGENAME>" = ["py.typed"]' >> $@
	@echo '[tool.setuptools.packages.find]' >> $@
	@echo 'where = ["src"]' >> $@
	@echo '[tool.distutils.egg_info]' >> $@
	@echo 'egg_base = "$(workspace)"' >> $@
	@echo '[tool.pytest.ini_options]' >> $@
	@echo 'addopts = "--quiet -rfE --showlocals --doctest-modules --doctest-continue-on-failure --cov=src --cov-branch"' >> $@
	@echo 'testpaths = ["src", "tests"]' >> $@
	@echo 'doctest_optionflags = "NORMALIZE_WHITESPACE ELLIPSIS"' >> $@
	@echo '[tool.pylint]' >> $@
	@echo 'max-line-length = 80' >> $@
	@echo 'good-names = ["df", "np"]' >> $@
	@echo '[tool.black]' >> $@
	@echo 'line-length = 80' >> $@
	@echo "include = '\.pyi?$$'" >> $@
	@echo "extend-exclude = '\( $(workspace) \)'" >> $@
	@echo '[tool.isort]' >> $@
	@echo 'profile = "black"' >> $@
	@echo '[tool.mypy]' >> $@
	@echo 'disallow_untyped_defs = true' >> $@
	@echo 'show_error_codes = true' >> $@
	@echo 'no_implicit_optional = true' >> $@
	@echo 'warn_return_any = true' >> $@
	@echo 'warn_unused_ignores = true' >> $@
	@echo 'exclude = ["scripts", "workspace", "tests"]' >> $@
	@echo '[tool.pyright]' >> $@
	@echo 'reportMissingTypeArgument = true' >> $@
	@echo 'strictListInference = true' >> $@
	@$(call log,$@ sample created,$(donestr))

$(license):
	@echo 'MIT License' > $@
	@echo '[get the text](https://choosealicense.com/licenses/mit/)' >> $@
	@$(call log,$@ sample created,$(donestr))

$(readme):
	@echo '# <PACKAGENAME>' > $@
	@echo 'Elevator pitch.' >> $@
	@echo '## Install' >> $@
	@echo '```' >> $@
	@echo 'git clone --depth 1 <URL>' >> $@
	@echo 'cd <PACKAGENAME>' >> $@
	@echo 'make dev' >> $@
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
	@$(call log,$@ sample created,$(donestr))

.PHONY: dev ### make development python environment
dev: venv requirements-dev
	@$(pip) install --force-reinstall --editable . > /dev/null
	@$(call log,development package installed,$(donestr))

requirements-dev := $(requirements)/dev.txt

.PHONY: requirements-dev ### install required pinned development packages
requirements-dev: $(requirements-dev)
	@$(pip) install -r $(requirements-dev) > /dev/null
	@$(call log,development requirements installed,$(donestr))

_init_dev_requirements := pytest pytest-cov pytest-mock pytest-datafiles pytest-datadir
_init_dev_requirements += mypy
_init_dev_requirements += black isort
_init_dev_requirements += pylint pylint-junit
_init_dev_requirements += pynvim

$(requirements-dev): $(python) | $(requirements)
	@for p in $(_init_dev_requirements); do \
		$(pip) install --upgrade $$p > /dev/null; \
		$(call add_line,$$($(pip) freeze | grep "$$p=="),$(requirements-dev)); \
		$(call log,$$p installed,$(donestr)); \
	done

package ?=

.PHONY: add-dev-requirment ### add development required package, e.g. make add-dev-requirements-dev package=...
add-dev-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) install --upgrade $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-dev))
	@$(call add_line,$$($(pip) freeze | grep "$(package)=="),$(requirements-dev))
	@$(call log,$$($(pip) freeze | grep "$(package)==") installed and pinned,$(donestr))

.PHONY: del-dev-requirment ### del development required package, e.g. make del-dev-requirements-dev package=...
del-dev-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) uninstall -y $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-dev))
	@$(call log,$(package) uninstalled and unpinned,$(donestr))

.PHONY: check ### format then test and lint
check: format test lint
	@$(call log,$@ completed,$(donestr))

.PHONY: format ###
format:
	@$(python) -m black .
	@$(python) -m isort --quiet --atomic .
	@$(call log,$@ completed,$(donestr))

.PHONY: test ### doctest and unittest with coverage and static code check
test: mypy
	@$(python) -m pytest
	@$(call add_line,.coverage,$(gitignore))
	@$(call log,$@ completed,$(donestr))

.PHONY: mypy ### static code check
mypy:
	@$(python) -m mypy --pretty --strict $(source_code)
	@$(call log,$@ completed,$(donestr))

.PHONY: lint ###
lint:
	@$(python) -m pylint $(source_code)
	@$(call log,$@ completed,$(donestr))

.PHONY: dist ### create distribution file
dist:
	@$(python) -m build --outdir $(workspace) --wheel > /dev/null
	@$(call log,dist wheel build at $(workspace),$(donestr))

.PHONY: run-test-daemon ### rerun test on change of any package
run-test-daemon:
	@find $(source_code) -name '*.py' | entr make test

notebooks := notebooks

$(notebooks):
	@mkdir -p $@

jupyter := $(venv)/bin/jupyter

.PHONY: run-jupyter ### venv jupyter lab
run-jupyter: $(jupyter) requirements-jupyter | $(notebooks)
	$< lab $(notebooks)

$(jupyter): $(python)
	@$(pip) install --upgrade jupyterlab > /dev/null
	@$(pip) freeze --all | grep 'jupyterlab==' > $(requirements-jupyter)
	@$(call log,jupyter installed,$(donestr))

requirements-jupyter := $(requirements)/jupyter.txt

.PHONY: requirements-jupyter ### install required pinned jupyter packages
requirements-jupyter: $(jupyter) $(requirements-jupyter)
	@$(pip) install -r $(requirements-jupyter) > /dev/null
	@$(call log,jupyter requirements installed,$(donestr))

_init_jupyter_requirements := jupyterlab-vim
_init_jupyter_requirements += jupyterlab-lsp
_init_jupyter_requirements += jupytext

$(requirements-jupyter): $(python) | $(requirements)
	@for p in $(_init_jupyter_requirements); do \
		$(pip) install --upgrade $$p > /dev/null; \
		$(call add_line,$$($(pip) freeze | grep "$$p=="),$(requirements-jupyter)); \
		$(call log,$$p installed,$(donestr)); \
	done

.PHONY: add-jupyter-requirment ### add jupyter required package, e.g. make add-jupyter-requirements-dev package=...
add-jupyter-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) install --upgrade $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-jupyter))
	@$(call add_line,$$($(pip) freeze | grep "$(package)=="),$(requirements-jupyter))
	@$(call log,$$($(pip) freeze | grep "$(package)==") installed and pinned,$(donestr))

.PHONY: del-jupyter-requirment ### del development required package, e.g. make del-jupyter-requirements-dev package=...
del-jupyter-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) uninstall -y $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-dev))
	@$(call log,$(package) uninstalled and unpinned,$(donestr))

.PHONY: setup-pyright ### local setup of pyright, WARN: requires npm etc
setup-pyright: $(pyrightconfig)
	@npm init -y
	@npm install pyright --save-dev
	@$(call add_line,node_modules/,$(gitignore))
	@$(call log,pyright local setup,$(donestr))
	@$(call log,consider adding to version control: pyrightconfig, package, package-lock,$(warnstr))

pyrightconfig := pyrightconfig.json

$(pyrightconfig):
	@echo "{" > $@
	@echo '"include": ["."],' >> $@
	@echo '"venvPath": ".",' >> $@
	@echo '"venv": ".venv"' >> $@
	@echo "}" >> $@

tensorboard := $(venv)/bin/tensorboard
tensorboardlogs := $(workspace)/tensorboard

$(tensorboardlogs):
	@mkdir -p $@

.PHONY: run-tensorboard ### venv tensorboard
run-tensorboard: $(tensorboard) requirements-tensorboard
	$< --logdir $(tensorboardlogs)

$(tensorboard): $(python)
	@$(pip) install --upgrade tensorboard > /dev/null
	@$(pip) freeze --all | grep 'tensorboard==' > $(requirements-tensorboard)
	@$(call log,jupyter installed,$(donestr))

requirements-tensorboard := $(requirements)/tensorboard.txt

.PHONY: requirements-tensorboard ### install required pinned tensorboard packages
requirements-tensorboard: $(tensorboard) $(requirements-tensorboard)
	@$(pip) install -r $(requirements-tensorboard) > /dev/null
	@$(call log,tensorboard requirements installed,$(donestr))
	@npm install --save-dev pyright

_init_tensorboard_requirements :=

$(requirements-tensorboard): $(python) | $(requirements)
	@for p in $(_init_tensorboard_requirements); do \
		$(pip) install --upgrade $$p > /dev/null; \
		$(call add_line,$$($(pip) freeze | grep "$$p=="),$(requirements-tensorboard)); \
		$(call log,$$p installed,$(donestr)); \
	done

.PHONY: add-tensorboard-requirment ### add tensorboard required package, e.g. make add-tensorboard-requirements-dev package=...
add-tensorboard-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) install --upgrade $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-tensorboard))
	@$(call add_line,$$($(pip) freeze | grep "$(package)=="),$(requirements-tensorboard))
	@$(call log,$$($(pip) freeze | grep "$(package)==") installed and pinned,$(donestr))

.PHONY: del-tensorboard-requirment ### del development required package, e.g. make del-tensorboard-requirements-dev package=...
del-tensorboard-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) uninstall -y $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-dev))
	@$(call log,$(package) uninstalled and unpinned,$(donestr))

.PHONY: clean-cache ###
clean-cache:
	@find . -name ".ipynb_checkpoints" -type d -exec rm -fr {} +
	@find . -name "*.pyc" -type f -exec rm -fr {} +
	@find . -name "__pycache__" -type d -exec rm -fr {} +
	@rm -rf .mypy_cache .pytest_cache .coverage
