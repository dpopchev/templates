MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --check-symlink-times

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:

.DEFAULT_GOAL := help

.PHONY: help ### show this menu
help:
	@sed -nr '/#{3}/{s/\.PHONY:/--/; s/\ *#{3}/:/; p;}' ${MAKEFILE_LIST} | sort

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
		sed --in-place '\,\b$(1)\b,d' $(2);\
		sort --unique --output $(2){,};\
	fi
endef


.PHONY: init ### template python project tracked with git

stamps := .stamps
source_code := src
tests := tests
workspace := workspace
requirements := requirements
packagerc := pyproject.toml
license := LICENSE
readme := README.md
gitignore := .gitignore

init: $(packagerc) $(license) $(readme) | $(source_code) $(tests) $(workspace) $(requirements) $(stamps)
	@git init > /dev/null
	@$(call log,git initialized,$(donestr))
	@$(call log,rename <PACKAGENAME> placeholder in $(packagerc) and $(readme),$(warnstr))
	@$(call log,config local git user attrs: name and email,$(warnstr))

$(source_code) $(tests) $(requirements):
	@mkdir -p $@

$(stamps) $(workspace):
	@mkdir -p $@
	@$(call add_line,$@,$(gitignore))
	@$(call log,git will ignore $@,$(donestr))

$(packagerc):
	@echo '[build-system]' > $@
	@echo 'requires = ["setuptools"]' >> $@
	@echo 'build-backend = "setuptools.build_meta"' >> $@
	@echo '' >> $@
	@echo '[project]' >> $@
	@echo 'name = "<PACKAGENAME>"' >> $@
	@echo 'version = "0.0.1"' >> $@
	@echo 'requires-python = ">=$(shell ($(python) --version 2> /dev/null || echo "3.10") | grep -oP "\d.\d+")"' >> $@
	@echo 'dependencies = ["toolz"]' >> $@
	@echo '' >> $@
	@echo '[tool.setuptools.package-data]' >> $@
	@echo '"<PACKAGENAME>" = ["py.typed"]' >> $@
	@echo '' >> $@
	@echo '[tool.setuptools.packages.find]' >> $@
	@echo 'where = ["src"]' >> $@
	@echo '' >> $@
	@echo '[tool.distutils.egg_info]' >> $@
	@echo 'egg_base = "$(workspace)"' >> $@
	@echo '' >> $@
	@echo '[tool.pytest.ini_options]' >> $@
	@echo 'addopts = "--quiet -rfE --showlocals --doctest-modules --doctest-continue-on-failure --cov=src --cov-branch"' >> $@
	@echo 'testpaths = ["src", "tests"]' >> $@
	@echo 'doctest_optionflags = "NORMALIZE_WHITESPACE ELLIPSIS"' >> $@
	@echo '' >> $@
	@echo '[tool.pylint]' >> $@
	@echo 'max-line-length = 80' >> $@
	@echo 'good-names = ["df", "np"]' >> $@
	@echo '' >> $@
	@echo '[tool.black]' >> $@
	@echo 'line-length = 80' >> $@
	@echo "include = '\.pyi?$$'" >> $@
	@echo "extend-exclude = '\( $(workspace) \)'" >> $@
	@echo '' >> $@
	@echo '[tool.isort]' >> $@
	@echo 'profile = "black"' >> $@
	@echo '' >> $@
	@echo '[tool.mypy]' >> $@
	@echo 'disallow_untyped_defs = true' >> $@
	@echo 'show_error_codes = true' >> $@
	@echo 'no_implicit_optional = true' >> $@
	@echo 'warn_return_any = true' >> $@
	@echo 'warn_unused_ignores = true' >> $@
	@echo 'exclude = ["scripts", "workspace", "tests"]' >> $@
	@echo '' >> $@
	@echo '[tool.pyright]' >> $@
	@echo 'reportMissingTypeArgument = true' >> $@
	@echo 'strictListInference = true' >> $@
	@$(call log,$@ template created,$(donestr))

$(license):
	@echo 'MIT License' > $@
	@echo '[get the text](https://choosealicense.com/licenses/mit/)' >> $@
	@$(call log,$@ template created,$(donestr))

$(readme):
	@echo '# <PACKAGENAME>' > $@
	@echo 'Elevator pitch.' >> $@
	@echo '' >> $@
	@echo '## Install' >> $@
	@echo '```' >> $@
	@echo 'git clone --depth 1 <URL>' >> $@
	@echo 'cd <PACKAGENAME>' >> $@
	@echo 'make dev' >> $@
	@echo 'make check' >> $@
	@echo '```' >> $@
	@echo 'If more context is needed then rename section to `Installation`.' >> $@
	@echo 'Put details into `Requirements` and `Install` subsections.' >> $@
	@echo '' >> $@
	@echo '## Usage' >> $@
	@echo 'Place examples with expected output.' >> $@
	@echo 'Start with `Setup` subsection for configuration.' >> $@
	@echo 'Break intu sub-...subsections using scenario/feature names.' >> $@
	@echo '' >> $@
	@echo '## Acknowledgment' >> $@
	@echo '- [makeareadme](https://www.makeareadme.com/)' >> $@
	@echo '' >> $@
	@echo '## License' >> $@
	@echo '[MIT](LICENSE)' >> $@
	@$(call log,$@ template created,$(donestr))

.PHONY: venv ### build local python environment

venv := .venv
pyseed ?= $(shell command -v python3 2> /dev/null)
python := $(venv)/bin/python
pip := $(venv)/bin/pip
requirements-pip := $(requirements)/pip.txt
stamp-venv := $(stamps)/venv
stamp-venv-requirements := $(stamps)/venv-requirements

venv: $(stamp-venv) $(stamp-venv-requirements)

$(stamp-venv): $(python) | $(stamps)
	@touch $@

$(python):
	@$(pyseed) -m venv $(venv)
	@$(call add_line,$(venv),$(gitignore))
	@$(call add_line,__pycache__,$(gitignore))
	@$(call add_line,*.py[cod],$(gitignore))
	@$(call log,venv created using $(pyseed),$(donestr))

$(stamp-venv-requirements): $(requirements-pip) | $(stamps)
	@$(pip) install -r $(requirements-pip)
	@$(call log,required pip installed,$(donestr))
	@touch $@

$(requirements-pip): | $(requirements)
	@$(pip) install --upgrade pip > /dev/null
	@$(pip) freeze --all | grep 'pip==' > $@
	@$(call log,pip version requirment set,$(donestr))
	@$(pip) install --upgrade build > /dev/null

.PHONY: clean-venv ###
clean-venv:
	@rm -rf $(venv)

.PHONY: dev ### make development python environment

requirements-dev := $(requirements)/dev.txt
stamp-dev := $(stamps)/dev
stamp-dev-requirements := $(stamps)/dev-requirements

dev: $(stamp-dev) $(stamp-dev-requirements)

$(stamp-dev): $(stamp-venv) | $(stamps)
	@$(pip) install --force-reinstall --editable . > /dev/null
	@$(call log,package installed into $(venv),$(donestr))
	@touch $@

$(stamp-dev-requirements): $(stamp-venv) $(requirements-dev) | $(stamps)
	@$(pip) install -r $(requirements-dev) > /dev/null
	@$(call log,development requirements installed,$(donestr))
	@touch $@

_init_dev_requirements := pytest pytest-cov pytest-mock pytest-datafiles pytest-datadir
_init_dev_requirements += mypy
_init_dev_requirements += black isort
_init_dev_requirements += pylint pylint_junit
_init_dev_requirements += pynvim

$(requirements-dev): | $(requirements)
	@for p in $(_init_dev_requirements); do \
		$(pip) install --upgrade $$p > /dev/null; \
		$(call add_line,$$($(pip) freeze | grep "$$p=="),$@); \
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
	@touch $(stamp-dev-requirements)

.PHONY: del-dev-requirment ### del development required package, e.g. make del-dev-requirements-dev package=...
del-dev-requirment:
	@if [[ -z "$(package)" ]]; then \
		$(call log,missing package name see help,$(failstr)); \
		exit 1;\
	fi
	@$(pip) uninstall -y $(package) > /dev/null
	@$(call del_line,$(package),$(requirements-dev))
	@$(call log,$(package) uninstalled and unpinned,$(donestr))
	@touch $(stamp-dev-requirements)

.PHONY: check ### format then test and lint
check: format test lint
	@$(call log,$@ completed,$(donestr))

.PHONY: format ###
format: $(python)
	@$(python) -m black .
	@$(python) -m isort --quiet --atomic .
	@$(call log,$@ completed,$(donestr))

.PHONY: test ### doctest and unittest with coverage and static code check
test: mypy $(python)
	@$(python) -m pytest
	@$(call add_line,.coverage,$(gitignore))
	@$(call log,$@ completed,$(donestr))

.PHONY: mypy ### static code check
mypy: $(python)
	@$(python) -m mypy --pretty --strict $(source_code)
	@$(call log,$@ completed,$(donestr))

.PHONY: lint ###
lint: $(python)
	@$(python) -m pylint $(source_code)
	@$(call log,$@ completed,$(donestr))

.PHONY: dist ### create distribution file
dist: $(python)
	@$(python) -m build --outdir $(workspace) --wheel > /dev/null
	@$(call log,dist wheel build at $(workspace),$(donestr))

.PHONY: run-test-daemon ### rerun test on change of any package
run-test-daemon:
	@find $(source_code) -name '*.py' | entr make test

.PHONY: jupyter ###

jupyter := $(venv)/bin/jupyter
requirements-jupyter := $(requirements)/jupyter.txt
stamp-jupyter := $(stamps)/jupyter
stamp-jupyter-requirements := $(stamps)/jupyter-requirements
notebooks := notebooks

$(notebooks):
	@mkdir -p $@

jupyter: $(stamp-jupyter) $(stamp-jupyter-requirements)

$(stamp-jupyter): $(stamp-venv) $(jupyter) | $(stamps)
	@touch $@

$(jupyter):
	@$(pip) install --upgrade jupyterlab > /dev/null
	@$(call add_line,*.ipynb,$(gitignore))
	@$(call log,jupyterlab installed,$(donestr))

$(stamp-jupyter-requirements): $(requirements-jupyter) | $(stamps)
	@$(pip) install -r $(requirements-jupyter) > /dev/null
	@$(call log,jupyter requirements installed,$(donestr))
	@touch $@

_init_jupyter_requirements := jupyterlab-vim
_init_jupyter_requirements += jupyterlab-lsp
_init_jupyter_requirements += jupytext

$(requirements-jupyter): | $(requirements)
	@$(pip) freeze --all | grep 'jupyterlab==' > $@
	@for p in $(_init_jupyter_requirements); do \
		$(pip) install --upgrade $$p > /dev/null; \
		$(call add_line,$$($(pip) freeze | grep "$$p=="),$@); \
		$(call log,$$p installed,$(donestr)); \
	done
	@$(call log,jupyter version requirment set,$(donestr))

.PHONY: run-jupyter ###
run-jupyter: $(stamp-jupyter) $(stamp-jupyter-requirements) | $(notebooks)
	$(jupyter) lab $(notebooks)

.PHONY: setup-local-nodejs ### jupyter uses nodejs, make latest lts locally available
setup-local-nodejs:
	@curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
	@$(call log,restart the shell,$(warnstr))
	@$(call log,run: nvm install --lts && nvm use --lts,$(warnstr))

.PHONY: setup-pyright ### local setup of pyright, WARN: requires npm etc

stamp-npm := $(stamps)/npm
stamp-pyright := $(stamps)/pyright
pyrightconfig := pyrightconfig.json
npm-packages := package.json
npm-lock := package-lock.json

setup-pyright: $(stamp-npm) $(stamp-pyright)

$(stamp-npm): $(npm-packages)
	@npm install
	@$(call log,npm packages updated,$(donestr))
	@$(call log,consider adding to version control: $(npm-packages) $(npm-lock),$(warnstr))
	@touch $@

$(npm-packages):
	@npm init -y
	@$(call log,local npm environment initialized,$(donestr))
	@$(call add_line,node_modules/,$(gitignore))

$(stamp-pyright):
	@npm install pyright --save-dev
	@echo "{" > $(pyrightconfig)
	@echo '"include": ["."],' >> $(pyrightconfig)
	@echo '"venvPath": ".",' >> $(pyrightconfig)
	@echo '"venv": ".venv"' >> $(pyrightconfig)
	@echo "}" >> $(pyrightconfig)
	@$(call log,consider adding to version control: $(pyrightconfig),$(warnstr))
	@touch $@

.PHONY: tensorboard ###

tensorboard := $(venv)/bin/tensorboard
requirements-tensorboard := $(requirements)/tensorboard.txt
stamp-tensorboard := $(stamps)/tensorboard
stamp-tensorboard-requirements := $(stamps)/tensorboard-requirements
tensorboardlogs := $(workspace)/tensorboard

tensorboard: $(stamp-tensorboard) $(stamp-tensorboard-requirements)

$(stamp-tensorboard): $(stamp-venv) $(tensorboard) | $(stamps)
	@touch $@

$(tensorboard):
	@$(pip) install --upgrade tensorboard >> /dev/null
	@$(call log,tensorboard installed,$(donestr))

$(stamp-tensorboard-requirements): $(requirements-tensorboard) | $(stamps)
	@$(pip) install -r $(requirements-tensorboard)
	@$(call log,tensorboard requirements installed,$(donestr))
	@touch $@

_init_tensorboard_requirements :=

$(requirements-tensorboard): | $(requirements)
	@$(pip) freeze --all | grep 'tensorboard==' > $@
	@for p in $(_init_tensorboard_requirements); do \
		$(pip) install --upgrade $$p > /dev/null; \
		$(call add_line,$$($(pip) freeze | grep "$$p=="),$@); \
		$(call log,$$p installed,$(donestr)); \
	done

.PHONY: run-tensorboard ###
run-tensorboard: $(stamp-tensorboard) $(stamp-tensorboard-requirements) | $(tensorboardlogs)
	$(tensorboard) --logdir $(tensorboardlogs)

$(tensorboardlogs):
	@mkdir -p $@

.PHONY: clean-cache ###
clean-cache:
	@find . -name ".ipynb_checkpoints" -type d -exec rm -fr {} +
	@find . -name "*.pyc" -type f -exec rm -fr {} +
	@find . -name "__pycache__" -type d -exec rm -fr {} +
	@rm -rf .mypy_cache .pytest_cache .coverage
