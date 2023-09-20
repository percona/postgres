# Copyright (c) 2022-2026, PostgreSQL Global Development Group

fsync_checker_sources = files(
  'fsync_checker_smgr.c',
)

if host_system == 'windows'
  fsync_checker_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'fsync_checker',
    '--FILEDESC', 'fsync_checker - SMGR extension for checking volatile relations',])
endif

fsync_checker = shared_module('fsync_checker',
  fsync_checker_sources,
  kwargs: pg_test_mod_args,
)
test_install_libs += fsync_checker

test_install_data += files(
  'fsync_checker.control',
)
