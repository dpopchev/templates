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
foo:= a b c
bar:= $(subst $(space),$(comma),$(foo))

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


components := componentA componentB
components_targets := $(patsubst %,install-%,$(components))
components_targets += $(patsubst %,uninstall-%,$(components))

.PHONY: components_targets
$(filter install-%,$(components_targets)): install-%:
	@echo 'Installing component: $*'

$(filter uninstall-%,$(components_targets)): uninstall-%:
	@echo 'Uninstalling component: $*'

.PHONY: install
install: $(filter install-%,$(components_targets))
	@echo 'Compile, copy executables, libraries etc.; may verify installation'
	@echo 'May verify installation'

.PHONY: uninstall
uninstall: $(filter uninstall-%,$(components_targets))
	@echo 'Revert install without cleaning builds'

.PHONY: clean
clean:
	@echo 'Delete all builds or files created by this makefile'
	@echo 'Maybe preserve configurations'

.PHONY: TAGS
TAGS:
	@echo 'Update tags file'

.PHONY: clean-TAGS
clean-TAGS:
	@echo 'Clear created tags file'

.PHONY: maintainer-clean
maintainer-clean: clean-TAGS
	@echo 'Clean up everything makefile can build used to maintain the package'

.PHONY: dist
dist:
	@echo 'Create distribution file of the project'

.PHONY: distclean
distclean:
	@echo 'Delete all created for packaging or building the program'

.PHONY: doc
doc:
	@echo 'Generate documentation'

.PHONY: test
test:
	@echo 'runs tests such as unittest, smoke, integration, whatever team decides'

.PHONY: check
check:
	@echo 'runs all tests such as `test` target plus lint coverage etc'

.PHONY: all
all:
	@echo 'Usually the default target, does it all'
