# syntax=docker/dockerfile:1

FROM alpine:3.16 as build

RUN \
  apk add --no-cache --upgrade --virtual=build-dependencies \
    make \
    g++ \
    gcc \
    cmake \
    ninja \
    git \
    gettext \
    xz \
    curl-dev \
    python3 \
    musl-libintl \
    linux-headers && \
  git clone https://github.com/transmission/transmission && \
  cd transmission; \
  git submodule update --init --recursive; \
  cmake \
      -S . \
      -B obj \
      -G Ninja \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DENABLE_CLI=ON \
      -DENABLE_DAEMON=ON \
      -DENABLE_GTK=OFF \
      -DENABLE_MAC=OFF \
      -DENABLE_QT=OFF \
      -DENABLE_TESTS=OFF \
      -DENABLE_UTILS=ON \
      -DENABLE_WEB=OFF \
      -DRUN_CLANG_TIDY=OFF; \
  cmake --build obj --config RelWithDebInfo; \
  cmake --build obj --config RelWithDebInfo --target install/strip;

# ----------------------------------------------------------------

FROM ghcr.io/linuxserver/baseimage-alpine:3.16 as runtime

ARG UNRAR_VERSION=6.1.7
ARG BUILD_DATE
ARG VERSION
ARG TRANSMISSION_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

COPY --from=build /usr/local/share/transmission /usr/share/transmission 
COPY --from=build /usr/local/share/doc/transmission /usr/share/doc/transmission
COPY --from=build /usr/local/bin/transmission-* /usr/bin/
COPY --from=build /usr/local/share/man/man1/transmission-* /usr/share/man/man1/

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --upgrade --virtual=build-dependencies \
    make \
    g++ \
    gcc && \
  echo "**** install packages ****" && \
  apk add --no-cache \
    openssl \
    p7zip \
    python3 && \
  echo "**** install unrar from source ****" && \
  mkdir /tmp/unrar && \
  curl -o \
    /tmp/unrar.tar.gz -L \
    "https://www.rarlab.com/rar/unrarsrc-${UNRAR_VERSION}.tar.gz" && \  
  tar xf \
    /tmp/unrar.tar.gz -C \
    /tmp/unrar --strip-components=1 && \
  cd /tmp/unrar && \
  make && \
  install -v -m755 unrar /usr/local/bin && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /root/.cache \
    /tmp/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 9091 51413/tcp 51413/udp
VOLUME /config
