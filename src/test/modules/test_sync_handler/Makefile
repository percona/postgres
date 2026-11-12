# src/test/modules/test_sync_handler/Makefile

MODULE_big = test_sync_handler
OBJS = \
	$(WIN32RES) \
	test_sync_handler.o
PGFILEDESC = "test_sync_handler - test module for sync handler registration"

EXTENSION = test_sync_handler
DATA = test_sync_handler--1.0.sql

TAP_TESTS = 1

# Tests require shared_preload_libraries=test_sync_handler which typical
# installcheck users do not have. Match test_slru's convention.
NO_INSTALLCHECK = 1

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = src/test/modules/test_sync_handler
top_builddir = ../../../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
