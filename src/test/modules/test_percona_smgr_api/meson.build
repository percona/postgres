# Copyright (c) 2026, Percona LLC and/or its affiliates

test_new_smgr_api_sources = files(
  'test_new_smgr_api.c',
)

if host_system == 'windows'
  test_new_smgr_api_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'test_new_smgr_api',
    '--FILEDESC', 'test_new_smgr_api - disable upstream smgr API',])
endif

test_new_smgr_api = shared_module('test_new_smgr_api',
  test_new_smgr_api_sources,
  kwargs: pg_test_mod_args,
)
test_install_libs += test_new_smgr_api

test_old_smgr_api_sources = files(
  'test_old_smgr_api.c',
)

if host_system == 'windows'
  test_old_smgr_api_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'test_old_smgr_api',
    '--FILEDESC', 'test_old_smgr_api - use upstream smgr API',])
endif

test_old_smgr_api = shared_module('test_old_smgr_api',
  test_old_smgr_api_sources,
  kwargs: pg_test_mod_args,
)
test_install_libs += test_old_smgr_api

test_install_data += files(
  'test_old_smgr_api.control',
  'test_old_smgr_api--1.0.sql',
)

tests += {
  'name': 'test_percona_smgr_api',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'tap': {
    'tests': [
      't/001_guard.pl',
    ],
  },
}
