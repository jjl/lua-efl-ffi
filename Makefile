SUBDIRS = gcc-lua gcc-lua-cdecl

CC        = gcc
AWK       = gawk
SED       = sed
CTAGS     = ctags

CFLAGS    = -std=c99 -D_XOPEN_SOURCE=700 -Wall -Wno-deprecated-declarations
CPPFLAGS  = -I$(FFI_CDECL_DIR)

GCCLUA    = gcc-lua/gcc/gcclua.so
FFI_CDECL = $(FFI_CDECL_DIR)/ffi-cdecl.lua

ifndef FFI_CDECL_DIR
  GCC_CDECL_DIR = gcc-lua-cdecl
  FFI_CDECL_DIR = $(GCC_CDECL_DIR)/ffi-cdecl
  ifdef LUA_PATH
    LUA_PATH := $(GCC_CDECL_DIR)/?.lua;$(GCC_CDECL_DIR)/?/init.lua;$(LUA_PATH)
  else
    LUA_PATH := $(GCC_CDECL_DIR)/?.lua;$(GCC_CDECL_DIR)/?/init.lua;;
  endif
  export LUA_PATH
endif

modules = eina ecore evas elementary
types = enums structs unions types functions defines
version = 1

eina_HEADERS = Eina.h
ecore_HEADERS = Ecore.h Ecore_Getopt.h
evas_HEADERS = Evas.h Evas_GL.h
elementary_HEADERS = Elementary.h

$(foreach mod,$(modules),$(eval $(mod)_CPPFLAGS=$(filter -I%,$(shell pkg-config --cflags $(mod)))))
CPPFLAGS := $(CPPFLAGS) $(foreach mod,$(modules),$($(mod)_CPPFLAGS))

$(foreach mod,$(modules),$(eval $(mod)_CFLAGS=$(filter-out -I%,$(shell pkg-config --cflags $(mod)))))
CFLAGS := $(CFLAGS) $(foreach mod,$(modules),$($(mod)_CFLAGS))

all: $(foreach mod,$(modules),$(mod).lua)

%.lua: %.cdecl.c %.lua.in gcc-lua
	$(CC) -S $(CPPFLAGS) $(CFLAGS) -fplugin=$(GCCLUA) -fplugin-arg-gcclua-script=$(FFI_CDECL) -fplugin-arg-gcclua-input=$*.lua.in -fplugin-arg-gcclua-output=$@ $<

%.lua.in: templates/lua.in.in
	$(SED) "s:<<MODULE>>:$*:g" $< > $@

%.collect.c: templates/collect.in
	$(SED) -e "s:<<MODULE>>:$*:g" $< > $@
	$(SED) $(foreach header,$($*_HEADERS), -e "s:<<HEADERS>>:#include <$(header)>\n<<HEADERS>>:") -i $@
	$(SED) -e '/<<HEADERS>>/d' -i $@

%.collect.E: %.collect.c
	$(CPP) $(CPPFLAGS) -o $@ $<

%.ctags: %.collect.E
	$(CTAGS) -x --language-force=c --c-kinds=degmpstu $< > $@

%.cdecl.c: templates/cdecl.in %.ctags $(foreach type,$(types),tools/awk-$(type))
	$(SED) -e "s:<<MODULE>>:$*:g" $< > $@
	$(SED) $(foreach header,$($*_HEADERS), -e "s:<<HEADERS>>:#include <$(header)>\n<<HEADERS>>:") -i $@
	$(SED) -e '/<<HEADERS>>/d' -i $@
	$(AWK) -v symbol_pattern=^$*_ $(foreach type,$(types), -f tools/awk-$(type)) $*.ctags >> $@

clean: $(SUBDIRS)
	$(RM) -r $(foreach mod,$(modules),$(foreach suffix,lua lua.in cdecl.c collect.E ctags,$(mod).$(suffix))) $(foreach mod,$(modules),$(foreach type,$(types),$(foreach suffix,cdecl.c,$(mod).$(type).$(suffix))))

.PHONY: clean $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)
