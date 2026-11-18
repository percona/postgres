# src/test/modules/test_xlog_crypt/Makefile

MODULE_big = test_xlog_crypt
OBJS = \
	$(WIN32RES) \
	test_xlog_crypt.o
PGFILEDESC = "test_xlog_crypt - toy PerconaXLogRecordCrypt hook for core tests"
EXTRA_INSTALL = contrib/pg_walinspect

TAP_TESTS = 1
NO_INSTALLCHECK = 1

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = src/test/modules/test_xlog_crypt
top_builddir = ../../../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
