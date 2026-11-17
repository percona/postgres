# src/test/modules/test_percona_smgr_api/Makefile

MODULES = test_new_smgr_api test_old_smgr_api
PGFILEDESC = "test_percona_smgr_api - test upstream smgr API guard"

EXTENSION = test_old_smgr_api
DATA = test_old_smgr_api--1.0.sql

TAP_TESTS = 1

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
subdir = src/test/modules/test_percona_smgr_api
top_builddir = ../../../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif
