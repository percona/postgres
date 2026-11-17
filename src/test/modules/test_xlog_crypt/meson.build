# Copyright (c) 2026, PostgreSQL Global Development Group

test_xlog_crypt_sources = files(
  'test_xlog_crypt.c',
)

if host_system == 'windows'
  test_xlog_crypt_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'test_xlog_crypt',
    '--FILEDESC', 'test_xlog_crypt - toy PerconaXLogRecordCrypt hook for core tests',])
endif

test_xlog_crypt = shared_module('test_xlog_crypt',
  test_xlog_crypt_sources,
  kwargs: pg_test_mod_args,
)
test_install_libs += test_xlog_crypt

tests += {
  'name': 'test_xlog_crypt',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'tap': {
    'tests': [
      't/001_ciphertext.pl',
      't/002_replication.pl',
      't/003_decrypt_failure.pl',
      't/004_overhead.pl',
      't/005_frontend_tools.pl',
      't/006_recovery_target.pl',
    ],
  },
}
