CC      := gcc
CFLAGS  := -std=c99 -Wall -O2 -g -D_REENTRANT
LIBS    := -lpthread -lm -lcrypto -lssl

TARGET  := $(shell uname -s | tr '[A-Z]' '[a-z]' 2>/dev/null || echo unknown)

ifeq ($(TARGET), sunos)
	CFLAGS += -D_PTHREADS -D_POSIX_C_SOURCE=200112L
	LIBS   += -lsocket
else ifeq ($(TARGET), darwin)
	# Per https://luajit.org/install.html: If MACOSX_DEPLOYMENT_TARGET
	# is not set then it's forced to 10.4, which breaks compile on Mojave.
	export MACOSX_DEPLOYMENT_TARGET = $(shell sw_vers -productVersion)
	LDFLAGS += -pagezero_size 10000 -image_base 100000000
	LIBS += -L/usr/local/opt/openssl/lib
	CFLAGS += -I/usr/local/include -I/usr/local/opt/openssl/include
else ifeq ($(TARGET), linux)
        # CFLAGS  += -D_POSIX_C_SOURCE=200809L -D_BSD_SOURCE
        CFLAGS  += -D_DEFAULT_SOURCE
	LIBS    += -ldl
	LDFLAGS += -Wl,-E
else ifeq ($(TARGET), freebsd)
	CFLAGS  += -D_DECLARE_C99_LDBL_MATH
	LDFLAGS += -Wl,-E
endif

SRC  := wrk.c net.c ssl.c aprintf.c stats.c script.c units.c \
		ae.c zmalloc.c http_parser.c tinymt64.c hdr_histogram.c
BIN  := wrk

ODIR := obj
OBJ  := $(patsubst %.c,$(ODIR)/%.o,$(SRC))

LDIR     = deps/lua/src
LIBS    := -llua $(LIBS)
CFLAGS  += -I$(LDIR)
LDFLAGS += -L$(LDIR)

AUTO_GENERATED_HEADER := $(CURDIR)/_wrk_lua_script.h

all: $(BIN)

clean:
	$(RM) $(BIN) obj/* $(AUTO_GENERATED_HEADER)
	@$(MAKE) -C deps/lua clean

$(BIN): $(OBJ)
	@echo LINK $(BIN)
	@$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

$(OBJ): config.h Makefile $(LDIR)/liblua.a | $(AUTO_GENERATED_HEADER) $(ODIR)

$(ODIR):
	@mkdir -p $@

$(ODIR)/%.o : %.c $(AUTO_GENERATED_HEADER)
	@echo CC $<
	@$(CC) $(CFLAGS) -c -o $@ $<

$(LDIR)/liblua.a:
	@echo Building LuaJIT...
	@$(MAKE) -C $(LDIR) BUILDMODE=static LUA_USE_APICHECK=1

$(AUTO_GENERATED_HEADER): $(CURDIR)/src/wrk.lua
	 # $(LDIR)/lua $(CURDIR)/bin2c.lua $(CURDIR)/src/wrk.lua > $(CURDIR)/src/_wrk_lua.h
	 # sh -c "xxd -i $(CURDIR)/src/wrk.lua > $(CURDIR)/_wrk_lua_script.h"
	 $(SHELL) -c 'cd $(CURDIR)/src && xxd -i wrk.lua > $@'

.PHONY: all clean
.SUFFIXES:
.SUFFIXES: .c .o .lua

vpath %.c   src
vpath %.h   src
vpath %.lua scripts
