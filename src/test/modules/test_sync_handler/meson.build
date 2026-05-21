# Copyright (c) 2026, PostgreSQL Global Development Group

test_sync_handler_sources = files(
  'test_sync_handler.c',
)

if host_system == 'windows'
  test_sync_handler_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'test_sync_handler',
    '--FILEDESC', 'test_sync_handler - test module for sync handler registration',])
endif

test_sync_handler = shared_module('test_sync_handler',
  test_sync_handler_sources,
  kwargs: pg_test_mod_args,
)
test_install_libs += test_sync_handler

test_install_data += files(
  'test_sync_handler.control',
  'test_sync_handler--1.0.sql',
)

tests += {
  'name': 'test_sync_handler',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'tap': {
    'tests': [
      't/001_basic.pl',
    ],
  },
}
