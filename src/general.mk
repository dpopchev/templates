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

FORCE:

inspect-%: FORCE
	@echo $($*)

all_components := componentA componentB
all_targets := $(patsubst %,setup-%,$(all_components))
all_targets += $(patsubst %,build-%,$(all_components))
all_targets += $(patsubst %,test-%,$(all_components))
all_targets += $(patsubst %,doc-%,$(all_components))
all_targets += $(patsubst %,install-%,$(all_components))
all_targets += $(patsubst %,uninstall-%,$(all_components))
all_targets += $(patsubst %,maintainer-clean-%,$(all_components))
all_targets += $(patsubst %,clean-%,$(all_components))

.PHONY: all_targets

TAGS:
	@echo 'creating stags file'

$(filter setup-%,$(all_targets)): setup-%:
	@echo 'setup for component: $*'

.PHONY: setup
setup: $(filter setup-%,$(all_targets))
	@echo 'setup up completed'

$(filter build-%,$(all_targets)): build-%:
	@echo 'build for component: $*'

.PHONY: build
build: $(filter build-%,$(all_targets))
	@echo 'build up completed'

$(filter test-%,$(all_targets)): test-%:
	@echo 'test for component: $*'

.PHONY: test
test: $(filter test-%,$(all_targets))
	@echo 'test up completed'

$(filter install-%,$(all_targets)): install-%:
	@echo 'install for component: $*'

.PHONY: install
install: $(filter install-%,$(all_targets))
	@echo 'install up completed'

$(filter uninstall-%,$(all_targets)): uninstall-%:
	@echo 'uninstall for component: $*'

.PHONY: uninstall
uninstall: $(filter uninstall-%,$(all_targets))
	@echo 'uninstall up completed'

$(filter maintainer-clean-%,$(all_targets)): maintainer-clean-%:
	@echo 'maintainer-clean for component: $*'

maintainer-clean-TAGS:
	@echo 'rm ctags file'

.PHONY: maintainer-clean
maintainer-clean: $(filter maintainer-clean-%,$(all_targets))
maintainer-clean: maintainer-clean-TAGS
	@echo 'maintainer-clean up completed'

$(filter clean-%,$(all_targets)): clean-%:
	@echo 'clean for component: $*'

.PHONY: clean
clean: $(filter clean-%,$(all_targets))
	@echo 'clean up completed'

# .PHONY: TAGS
# TAGS:
# 	@echo 'Update tags file'
#
# .PHONY: clean-TAGS
# clean-TAGS:
# 	@echo 'Clear created tags file'
#
# .PHONY: maintainer-clean
# maintainer-clean: clean-TAGS
# 	@echo 'Clean up everything makefile can build used to maintain the package'
#
# .PHONY: dist
# dist:
# 	@echo 'Create distribution file of the project'
#
# .PHONY: distclean
# distclean:
# 	@echo 'Delete all created for packaging or building the program'
#
# .PHONY: doc
# doc:
# 	@echo 'Generate documentation'
#
# .PHONY: test
# test:
# 	@echo 'runs tests such as unittest, smoke, integration, whatever team decides'
#
# .PHONY: check
# check:
# 	@echo 'runs all tests such as `test` target plus lint coverage etc'
#
# .PHONY: all
# all:
# 	@echo 'Usually the default target, does it all'
