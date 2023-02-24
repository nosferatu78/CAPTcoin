# Copyright (c) 2009-2010 Satoshi Nakamoto
# Distributed under the MIT/X11 software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

USE_UPNP:=1
USE_IPV6:=1

LINK:=$(CXX)
SRC:=src
OBJ:=$(SRC)/obj

DEFS=-DBOOST_SPIRIT_THREADSAFE

DEFS += $(addprefix -I,$(CURDIR) $(OBJ) $(BOOST_INCLUDE_PATH) $(BDB_INCLUDE_PATH) $(OPENSSL_INCLUDE_PATH))
LIBS = $(addprefix -L,$(BOOST_LIB_PATH) $(BDB_LIB_PATH) $(OPENSSL_LIB_PATH))

TESTDEFS = -DTEST_DATA_DIR=$(abspath test/data)

LMODE = dynamic
LMODE2 = dynamic
ifdef STATIC
	LMODE = static
	ifeq (${STATIC}, all)
		LMODE2 = static
	endif
else
	TESTDEFS += -DBOOST_TEST_DYN_LINK
endif

# for boost 1.37, add -mt to the boost libraries
LIBS += \
 -Wl,-B$(LMODE) \
   -l boost_system$(BOOST_LIB_SUFFIX) \
   -l boost_filesystem$(BOOST_LIB_SUFFIX) \
   -l boost_program_options$(BOOST_LIB_SUFFIX) \
   -l boost_thread$(BOOST_LIB_SUFFIX) \
   -l db_cxx$(BDB_LIB_SUFFIX) \
   -l ssl \
   -l crypto

ifndef USE_UPNP
	override USE_UPNP = -
endif
ifneq (${USE_UPNP}, -)
	LIBS += -l miniupnpc
	DEFS += -DUSE_UPNP=$(USE_UPNP)
endif

ifneq (${USE_IPV6}, -)
	DEFS += -DUSE_IPV6=$(USE_IPV6)
endif

LIBS+= \
 -Wl,-B$(LMODE2) \
   -l z \
   -l dl \
   -l pthread


# Hardening
# Make some classes of vulnerabilities unexploitable in case one is discovered.
#
    # This is a workaround for Ubuntu bug #691722, the default -fstack-protector causes
    # -fstack-protector-all to be ignored unless -fno-stack-protector is used first.
    # see: https://bugs.launchpad.net/ubuntu/+source/gcc-4.5/+bug/691722
    HARDENING=-fno-stack-protector

    # Stack Canaries
    # Put numbers at the beginning of each stack frame and check that they are the same.
    # If a stack buffer if overflowed, it writes over the canary number and then on return
    # when that number is checked, it won't be the same and the program will exit with
    # a "Stack smashing detected" error instead of being exploited.
    HARDENING+=-fstack-protector-all -Wstack-protector

    # Make some important things such as the global offset table read only as soon as
    # the dynamic linker is finished building it. This will prevent overwriting of addresses
    # which would later be jumped to.
    LDHARDENING+=-Wl,-z,relro -Wl,-z,now

    # Build position independent code to take advantage of Address Space Layout Randomization
    # offered by some kernels.
    # see doc/build-unix.txt for more information.
    ifdef PIE
        HARDENING+=-fPIE
        LDHARDENING+=-pie
    endif

    # -D_FORTIFY_SOURCE=2 does some checking for potentially exploitable code patterns in
    # the source such overflowing a statically defined buffer.
    HARDENING+=-D_FORTIFY_SOURCE=2
#


DEBUGFLAGS=-g

# CXXFLAGS can be specified on the make command line, so we use xCXXFLAGS that only
# adds some defaults in front. Unfortunately, CXXFLAGS=... $(CXXFLAGS) does not work.
xCXXFLAGS=-O2 -msse2 -pthread -Wall -Wextra -Wformat -Wformat-security -Wno-unused-parameter \
    $(DEBUGFLAGS) $(DEFS) $(HARDENING) $(CXXFLAGS)

# LDFLAGS can be specified on the make command line, so we use xLDFLAGS that only
# adds some defaults in front. Unfortunately, LDFLAGS=... $(LDFLAGS) does not work.
xLDFLAGS=$(LDHARDENING) $(LDFLAGS)

OBJS= \
    $(OBJ)/alert.o \
    $(OBJ)/version.o \
    $(OBJ)/checkpoints.o \
    $(OBJ)/netbase.o \
    $(OBJ)/addrman.o \
    $(OBJ)/crypter.o \
    $(OBJ)/key.o \
    $(OBJ)/db.o \
    $(OBJ)/init.o \
    $(OBJ)/irc.o \
    $(OBJ)/keystore.o \
    $(OBJ)/main.o \
    $(OBJ)/net.o \
    $(OBJ)/protocol.o \
    $(OBJ)/bitcoinrpc.o \
    $(OBJ)/rpcdump.o \
    $(OBJ)/rpcnet.o \
    $(OBJ)/rpcmining.o \
    $(OBJ)/rpcwallet.o \
    $(OBJ)/rpcblockchain.o \
    $(OBJ)/rpcrawtransaction.o \
    $(OBJ)/script.o \
    $(OBJ)/sync.o \
    $(OBJ)/util.o \
    $(OBJ)/wallet.o \
    $(OBJ)/walletdb.o \
    $(OBJ)/noui.o \
    $(OBJ)/kernel.o \
    $(OBJ)/pbkdf2.o \
    $(OBJ)/scrypt_mine.o \
    $(OBJ)/scrypt-x86.o \
    $(OBJ)/scrypt-x86_64.o


all: CAPTcoind

test check: test_CAPTcoin FORCE
	./test_CAPTcoin

# auto-generated dependencies:
-include $(OBJ)/*.P
-include obj-test/*.P

$(OBJ)/build.h: FORCE
	/bin/sh ../share/genbuild.sh $(OBJ)/build.h
version.cpp: $(OBJ)/build.h
DEFS += -DHAVE_BUILD_INFO

$(OBJ)/scrypt-x86.o: scrypt-x86.S
	$(CXX) -c $(xCXXFLAGS) -MMD -o $@ $<

$(OBJ)/scrypt-x86_64.o: scrypt-x86_64.S
	$(CXX) -c $(xCXXFLAGS) -MMD -o $@ $<

$(OBJ)/%.o: %.cpp
	$(CXX) -c $(xCXXFLAGS) -MMD -MF $(@:%.o=%.d) -o $@ $<
	@cp $(@:%.o=%.d) $(@:%.o=%.P); \
	  sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
	      -e '/^$$/ d' -e 's/$$/ :/' < $(@:%.o=%.d) >> $(@:%.o=%.P); \
	  rm -f $(@:%.o=%.d)

CAPTcoind: $(OBJS:$(OBJ)/%=$(OBJ)/%)
	$(LINK) $(xCXXFLAGS) -o $@ $^ $(xLDFLAGS) $(LIBS)

TESTOBJS := $(patsubst test/%.cpp,obj-test/%.o,$(wildcard test/*.cpp))

obj-test/%.o: test/%.cpp
	$(CXX) -c $(TESTDEFS) $(xCXXFLAGS) -MMD -MF $(@:%.o=%.d) -o $@ $<
	@cp $(@:%.o=%.d) $(@:%.o=%.P); \
	  sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
	      -e '/^$$/ d' -e 's/$$/ :/' < $(@:%.o=%.d) >> $(@:%.o=%.P); \
	  rm -f $(@:%.o=%.d)

test_CAPTcoin: $(TESTOBJS) $(filter-out $(OBJ)/init.o,$(OBJS:$(OBJ)/%=$(OBJ)/%))
	$(LINK) $(xCXXFLAGS) -o $@ $(LIBPATHS) $^ -Wl,-B$(LMODE) -lboost_unit_test_framework $(xLDFLAGS) $(LIBS)

clean:
	-rm -f CAPTcoind test_CAPTcoin
	-rm -f $(OBJ)/*.o
	-rm -f obj-test/*.o
	-rm -f $(OBJ)/*.P
	-rm -f obj-test/*.P
	-rm -f $(OBJ)/build.h

FORCE:
