FROM casjaysdevdocker/alpine:latest as build

ENV PYTHON_VERSION 3.11.0a5
# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 21.2.4
# https://github.com/docker-library/python/issues/365
ENV PYTHON_SETUPTOOLS_VERSION 58.1.0
# https://github.com/pypa/get-pip
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/2caf84b14febcda8077e59e9b8a6ef9a680aa392/public/get-pip.py

ENV PATH /usr/local/bin:$PATH
RUN set -eux; \
  apk add --no-cache \
  ca-certificates \
  tzdata 

RUN set -eux; \
  \
  apk add --no-cache --virtual .build-deps \
  gnupg \
  tar \
  xz \
  bluez-dev \
  bzip2-dev \
  coreutils \
  dpkg-dev dpkg \
  expat-dev \
  findutils \
  gcc \
  gdbm-dev \
  libc-dev \
  libffi-dev \
  libnsl-dev \
  libtirpc-dev \
  linux-headers \
  make \
  ncurses-dev \
  openssl-dev \
  pax-utils \
  readline-dev \
  sqlite-dev \
  tcl-dev \
  tk \
  tk-dev \
  util-linux-dev \
  xz-dev \
  zlib-dev \
  ; \
  \
  wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"; \
  mkdir -p /usr/src/python; \
  tar --extract --directory /usr/src/python --strip-components=1 --file python.tar.xz; \
  rm python.tar.xz; \
  \
  cd /usr/src/python; \
  gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
  ./configure \
  --build="$gnuArch" \
  --enable-loadable-sqlite-extensions \
  --enable-optimizations \
  --enable-option-checking=fatal \
  --enable-shared \
  --with-lto \
  --with-system-expat \
  --with-system-ffi \
  --without-ensurepip \
  ; \
  nproc="$(nproc)"; \
  make -j "$nproc" \
  # set thread stack size to 1MB so we don't segfault before we hit sys.getrecursionlimit()
  # https://github.com/alpinelinux/aports/commit/2026e1259422d4e0cf92391ca2d3844356c649d0
  EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
  LDFLAGS="-Wl,--strip-all" \
  ; \
  make install; \
  cd /; \
  rm -rf /usr/src/python; \
  \
  find /usr/local -depth \
  \( \
  \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
  -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' -o -name '*.a' \) \) \
  \) -exec rm -rf '{}' + \
  ; \
  \
  find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
  | tr ',' '\n' \
  | sort -u \
  | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  | xargs -rt apk add --no-network --virtual .python-rundeps \
  ; \
  apk del --no-network .build-deps; \
  python3 --version

# make some useful symlinks that are expected to exist ("/usr/local/bin/python" and friends)
RUN set -eux; \
  for src in idle3 pydoc3 python3 python3-config; do \
  dst="$(echo "$src" | tr -d 3)"; \
  [ -s "/usr/local/bin/$src" ]; \
  [ ! -e "/usr/local/bin/$dst" ]; \
  ln -svT "/usr/local/bin/$src" "/usr/local/bin/$dst"; \
  done

RUN set -eux; \
  \
  wget -O get-pip.py "$PYTHON_GET_PIP_URL"; \
  python get-pip.py \
  --disable-pip-version-check \
  --no-cache-dir \
  "pip==$PYTHON_PIP_VERSION" \
  "setuptools==$PYTHON_SETUPTOOLS_VERSION" \
  ; \
  pip --version; \
  \
  find /usr/local -depth \
  \( \
  \( -type d -a \( -name test -o -name tests -o -name idle_test \) \) \
  -o \
  \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
  \) -exec rm -rf '{}' + \
  ; \
  rm -f get-pip.py

COPY ./bin/. /usr/local/bin/

FROM scratch 

COPY --from=build / /

EXPOSE 1-65535

WORKDIR /app
VOLUME [ "/app" ]
ENTRYPOINT [ "/usr/local/bin/entrypoint-python.sh" ]
CMD [ "/bin/bash","-l" ]
