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

# standard status messages to be used for logging;
# length is fixed to 4 charters
TERM ?=
done := done
fail := fail
info := info

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
build_dir := build

$(src_dir) $(tests_dir):
	@mkdir -p $@

$(build_dir):
	@mkdir -p $@
	@$(call add_gitignore,$@/)

.PHONY: build-object ### recipe building object
build-object: build/build.o

build/build.o: | $(build_dir)
	@touch $@
	@$(call log,'built object: $(notdir $@)',$(done))

.PHONY: clean-build ###
clean-build:
	@rm -rf $(build_dir)
	@$(call del_gitignore,$(build_dir))
	@$(call log,'$@',$(done))

.PHONY: build-stamped ### recipe using stamp idiom
build-stamped: $(stamp_dir)/stamped.stamp

$(stamp_dir)/stamped.stamp: | $(stamp_dir)
	@touch $@
	@$(call log,'making a build using stamp idiom',$(done))

.PHONY: recipe ### recipe depending on stamped built
recipe:
	@if [ ! -e $(stamp_dir)/stamped.stamp ]; then \
		echo 'Required build-stamped recipe not executed yet';\
		echo 'do: make build-stamped first';\
		false;\
	fi
	@$(call log,'recipe execution',$(done))

module ?= module
args ?= ''
.PHONY: run ### run <module>, pass <args>
run:
ifeq ($(module),module)
	@echo 'run with $(module) using $(args)'
else
	@echo 'run with $(module) using $(args)'
endif

.PHONY: clean ###
clean: clean-build
	@rm -rf $(stamp_dir)
