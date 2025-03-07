# Copyright (c) 2022-2025, PostgreSQL Global Development Group

postgres_fdw_sources = files(
  'connection.c',
  'deparse.c',
  'option.c',
  'postgres_fdw.c',
  'shippable.c',
)

if host_system == 'windows'
  postgres_fdw_sources += rc_lib_gen.process(win32ver_rc, extra_args: [
    '--NAME', 'postgres_fdw',
    '--FILEDESC', 'postgres_fdw - foreign data wrapper for PostgreSQL',])
endif

postgres_fdw = shared_module('postgres_fdw',
  postgres_fdw_sources,
  kwargs: contrib_mod_args + {
    'dependencies': contrib_mod_args['dependencies'] + [libpq],
  },
)
contrib_targets += postgres_fdw

if llvm.found()
  llvm_contrib_fdw_cflags = [
    '-I@0@/src/interfaces/libpq'.format(meson.source_root()),
  ]

  llvm_contrib_sources += {
    'postgres_fdw': {
      'sources': postgres_fdw_sources,
      'extra_args': llvm_contrib_fdw_cflags,
    }
  }
endif

install_data(
  'postgres_fdw.control',
  'postgres_fdw--1.0.sql',
  'postgres_fdw--1.0--1.1.sql',
  'postgres_fdw--1.1--1.2.sql',
  kwargs: contrib_data_args,
)

tests += {
  'name': 'postgres_fdw',
  'sd': meson.current_source_dir(),
  'bd': meson.current_build_dir(),
  'regress': {
    'sql': [
      'postgres_fdw',
      'query_cancel',
    ],
    'regress_args': ['--dlpath', meson.build_root() / 'src/test/regress'],
  },
  'tap': {
    'tests': [
      't/001_auth_scram.pl',
    ],
  },
}
