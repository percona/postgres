FROM ubuntu:22.04

RUN mkdir /pg

RUN DEBIAN_FRONTEND=noninteractiveDEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libreadline6-dev systemtap-sdt-dev \
        zlib1g-dev libssl-dev libpam0g-dev bison flex \
        libipc-run-perl -y docbook-xsl docbook-xsl libxml2 libxml2-utils \
        libxml2-dev libxslt-dev xsltproc libkrb5-dev libldap2-dev \
        libsystemd-dev gettext tcl-dev libperl-dev pkg-config clang-11 \
        llvm-11 llvm-11-dev libselinux1-dev python3-dev \
        uuid-dev liblz4-dev meson ninja-build  \
        gpg wget libcurl4-openssl-dev libhttp-server-simple-perl git

ADD --keep-git-dir=true https://github.com/Percona-Lab/postgres.git /pg/src

WORKDIR /pg/src

RUN git fetch
RUN git checkout TDE_REL_17_STABLE
RUN git submodule update --init --recursive

RUN meson setup build --prefix /pg/ --buildtype=release 
WORKDIR /pg/src/build
RUN ninja install

WORKDIR /pg/

RUN rm -rf src

RUN useradd pg
RUN chown -R pg /pg

USER pg

RUN bash -c "bin/initdb -D data -A password --pwfile=<(echo pg)"
RUN echo "shared_preload_libraries = 'pg_tde' " >> data/postgresql.conf

STOPSIGNAL SIGINT
EXPOSE 5432

CMD bin/postgres -D data 