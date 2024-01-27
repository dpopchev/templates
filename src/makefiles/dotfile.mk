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

backup_suffix := dpopchevbak
define backup_config
if [ -e "$(1)" ]; then \
	mv --force --no-target-directory --backup=numbered \
	"$(1)" "$(1).$(backup_suffix)";\
fi
endef

stamp_suffix := stamp
stamp_dir := .stamps

$(stamp_dir):
	@$(call add_gitignore,$@)
	@mkdir -p $@

.PHONY: clean-stampdir ### reset operation tracking
clean-stampdir:
	@rm -rf $(stamp_dir)
	@$(call del_gitignore,$(stamp_dir))

src_dir := src

$(src_dir):
	@mkdir -p $@

dotfiles +=
config_dsts += $(addprefix ${HOME}/.,$(dotfiles))
config_stamps += $(addprefix $(stamp_dir)/,$(addsuffix .$(stamp_suffix),$(dotfiles)))
install_dotfiles += $(addprefix install-,$(dotfiles))
uninstall_dotfiles += $(subst install,uninstall,$(install_dotfiles))

.PHONY: install ###
install: $(install_dotfiles)

.PHONY: $(install_dotfiles)
$(install_dotfiles): install-%: $(stamp_dir)/%.$(stamp_suffix)

$(config_stamps): $(stamp_dir)/%.$(stamp_suffix): | $(stamp_dir)
	@$(call backup_config,$(filter %$*,$(config_dsts)))
	@ln -s $(realpath $(src_dir)/$(filter %$*,$(dotfiles))) $(filter %$*,$(config_dsts))
	@touch $@
	@$(call log,'install dotfile $*',$(donestr))

.PHONY: uninstall ###
uninstall: $(uninstall_dotfiles)

.PHONY: $(uninstall_dotfiles)
$(uninstall_dotfiles): uninstall-%:
	@if [ ! -e "$(filter %$*.$(stamp_suffix),$(config_stamps))" ]; then \
		$(call log,'$* dotfile isntallation not tracked by this repo instance',$(failstr));\
		exit 2;\
	fi
	@rm --force $(filter %$*,$(config_dsts))
	@$(call log,'$* dotfile removed',$(donestr))
	@if [ ! -e "$(filter %$*,$(config_dsts)).$(backup_suffix)" ]; then \
		$(call log,'$* dotfile backup not found',$(warnstr)); \
	fi
	@if [ -e "$(filter %$*,$(config_dsts)).$(backup_suffix)" ]; then \
		mv --force $(filter %$*,$(config_dsts)).$(backup_suffix) $(filter %$*,$(config_dsts));\
		$(call log,'$* dotfile restored',$(donestr));\
	fi
	@rm --force $(stamp_dir)/$*.$(stamp_suffix)

.PHONY: clean ###
clean:
	@rm -rf $(stamp_dir)
