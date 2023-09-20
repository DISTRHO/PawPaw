
# Case conversion macros. This is inspired by the 'up' macro from gmsl
# (http://gmsl.sf.net). It is optimised very heavily because these macros
# are used a lot. It is about 5 times faster than forking a shell and tr.
#
# The caseconvert-helper creates a definition of the case conversion macro.
# After expansion by the outer $(eval ), the UPPERCASE macro is defined as:
# $(strip $(eval __tmp := $(1))  $(eval __tmp := $(subst a,A,$(__tmp))) ... )
# In other words, every letter is substituted one by one.
#
# The caseconvert-helper allows us to create this definition out of the
# [FROM] and [TO] lists, so we don't need to write down every substition
# manually. The uses of $ and $$ quoting are chosen in order to do as
# much expansion as possible up-front.
#
# Note that it would be possible to conceive a slightly more optimal
# implementation that avoids the use of __tmp, but that would be even
# more unreadable and is not worth the effort.

[FROM] := a b c d e f g h i j k l m n o p q r s t u v w x y z - .
[TO]   := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _ _

define caseconvert-helper
$(1) = $$(strip \
	$$(eval __tmp := $$(1))\
	$(foreach c, $(2),\
		$$(eval __tmp := $$(subst $(word 1,$(subst :, ,$c)),$(word 2,$(subst :, ,$c)),$$(__tmp))))\
	$$(__tmp))
endef

$(eval $(call caseconvert-helper,UPPERCASE,$(join $(addsuffix :,$([FROM])),$([TO]))))
$(eval $(call caseconvert-helper,LOWERCASE,$(join $(addsuffix :,$([TO])),$([FROM]))))

# Sanitize macro cleans up generic strings so it can be used as a filename
# and in rules. Particularly useful for VCS version strings, that can contain
# slashes, colons (OK in filenames but not in rules), and spaces.
sanitize = $(subst $(space),_,$(subst :,_,$(subst /,_,$(strip $(1)))))

# github(user,package,version): returns site of GitHub repository
github = https://github.com/$(1)/$(2)/archive/$(3)

# custom for PawPaw

PKG = $(call UPPERCASE,$(call sanitize,$(pkgname)))
$(PKG)_PKGDIR = $(CURDIR)/mod-plugin-builder/plugins/package/$(pkgname)

BR2_TARGET_OPTIMIZATION =

MAKE1 = make -j1
PARALLEL_JOBS = $(shell nproc)

WORKDIR ?= $(HOME)/mod-workdir
HOST_DIR = $(WORKDIR)/moddwarf-new/host

TARGET_CFLAGS = $(CFLAGS)
TARGET_CXXFLAGS = $(CXXFLAGS)
TARGET_LDFLAGS = $(LDFLAGS)

TARGET_DIR = $(PAWPAW_PREFIX)

define generic-package

endef

define cmake-package

define $(PKG)CONFIGURE_CMDS
	(cd $$($$(PKG)_DIR) && \
	rm -f CMakeCache.txt && \
	$$(CMAKE) $$($$(PKG)_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX='/usr' \
		--no-warn-unused-cli \
		$$($$(PKG)CONF_OPTS) \
	)
endef

define $(PKG)BUILD_CMDS
	$(MAKE) -C $$($$(PKG)_DIR)
endef

ifndef $(PKG)INSTALL_TARGET_CMDS
define $(PKG)INSTALL_TARGET_CMDS
	$(MAKE) -C $$($$(PKG)_DIR) DESTDIR=$(PAWPAW_PREFIX)
endef
endif

endef

include $(CURDIR)/mod-plugin-builder/plugins/package/$(pkgname)/$(pkgname).mk

$(PKG)_VERSION = $(call sanitize,$(strip $($(PKG)VERSION)))
$(PKG)_DIR = $(PAWPAW_BUILDDIR)/$(pkgname)-$($(PKG)_VERSION)

# TODO change according to SITE_METHOD?
$(PKG)_DLFILE = $(PAWPAW_DOWNLOADDIR)/$(pkgname)-$($(PKG)_VERSION).tar.gz

STAMP_EXTRACTED  = $($(PKG)_DIR)/.stamp_extracted
STAMP_CONFIGURED = $($(PKG)_DIR)/.stamp_configured
STAMP_BUILT      = $($(PKG)_DIR)/.stamp_built
STAMP_INSTALLED  = $($(PKG)_DIR)/.stamp_installed

TMPDIR = /tmp/PawPaw
TMPNAME = git-dl

all: $(STAMP_INSTALLED)

$(STAMP_INSTALLED): $(STAMP_BUILT)
	$($(PKG)INSTALL_TARGET_CMDS)
	touch $@

$(STAMP_BUILT): $(STAMP_CONFIGURED)
	$($(PKG)BUILD_CMDS)
	touch $@

$(STAMP_CONFIGURED): $(STAMP_EXTRACTED)
	$($(PKG)CONFIGURE_CMDS)
	touch $@

# TODO change according to SITE_METHOD?
$(STAMP_EXTRACTED): $($(PKG)_DLFILE)
	mkdir -p '$($(PKG)_DIR)'
	tar -xf '$($(PKG)_DLFILE)' -C '$($(PKG)_DIR)' --strip-components=1
	touch $@

$($(PKG)_DLFILE):
ifeq ($($(PKG)SITE_METHOD),git)
	rm -rf '$(TMPDIR)'
	git clone --recursive '$($(PKG)SITE)' '$(TMPDIR)/$(TMPNAME)' && \
	git -C '$(TMPDIR)/$(TMPNAME)' checkout '$($(PKG)VERSION)' && \
	git -C '$(TMPDIR)/$(TMPNAME)' submodule update --recursive --init && \
	tar --exclude='.git' -czf '$($(PKG)_DLFILE)' -C '$(TMPDIR)' '$(TMPNAME)'
	rm -rf '$(TMPDIR)'
else
	wget -O '$($(PKG)_DLFILE)' '$($(PKG)SITE).tar.gz'
endif
