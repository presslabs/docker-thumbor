FROM debian:buster-slim as build-tools
WORKDIR /usr/src
RUN set -ex && apt-get update
RUN set -ex && apt-get install --no-install-recommends -y \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        git \
        libtool \
        nasm \
        pkg-config

RUN set -ex && apt-get install --no-install-recommends -y \
        libjbig-dev \
        liblcms2-dev \
        liblzma-dev \
        libpng-dev \
        libwebp-dev \
        libzstd-dev

ENV MOZJPEG_VERSION=v3.3.1
WORKDIR /usr/src/mozjpeg
RUN set -ex \
    && git clone https://github.com/mozilla/mozjpeg.git . \
    && git checkout ${MOZJPEG_VERSION}

RUN set -ex \
    && autoreconf -fiv \
    && ./configure --with-jpeg8 \
    && make \
    && make install \
    && rm -rf /opt/mozjpeg/share

ENV GIFSICLE_VERSION=v1.92
WORKDIR /usr/src/gifsicle
RUN set -ex \
    && git clone https://github.com/kohler/gifsicle.git . \
    && git checkout ${GIFSICLE_VERSION}

RUN set -ex \
    && autoreconf -i \
    && ./configure --prefix=/opt/gifsicle --disable-gifview --disable-gifdiff \
    && make \
    && make install \
    && rm -rf /opt/gifsicle/share

ENV PNGQUANT_VERSION=2.12.6
WORKDIR /usr/src/pngquant
RUN set -ex \
    && git clone https://github.com/kornelski/pngquant  . \
    && git checkout --recurse-submodules ${PNGQUANT_VERSION}

RUN set -ex \
    && ./configure --prefix=/opt/pngquant \
    && make \
    && make install \
    && rm -rf /opt/pngquant/share

WORKDIR /usr/src/pngquant/lib
RUN set -ex \
    && ./configure --prefix=/opt/pngquant \
    && make libimagequant.so \
    && make install \
    && rm -rf /opt/pngquant/share

ENV LIBTIFF_VERSION=v4.1.0
WORKDIR /usr/src/libtiff
RUN set -ex \
    && git clone https://gitlab.com/libtiff/libtiff.git . \
    && git checkout ${LIBTIFF_VERSION}

RUN set -ex \
    && autoreconf -i \
    && ./configure --prefix=/opt/libtiff \
        --with-jpeg-include-dir=/opt/mozjpeg/include \
        --with-jpeg-lib-dir=/opt/mozjpeg/lib64 \
    && make \
    && make install \
    && rm -rf /opt/libtiff/share


# Build a virtualenv using the appropriate Debian release
# * Install python3-venv for the built-in Python3 venv module (not installed by default)
# * Install gcc libpython3-dev to compile C Python modules
# * Update pip to support bdist_wheel
FROM debian:buster-slim AS build-venv
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-suggests --no-install-recommends --yes \
        gcc \
        curl \
        libcurl4-openssl-dev \
        libglib2.0-dev \
        libjbig-dev \
        liblcms2-dev \
        libpng-dev \
        libssl-dev \
        libwebp-dev \
        python-dev \
        python-virtualenv \
        zlib1g-dev

COPY --from=build-tools /opt/ /opt/
ENV LD_LIBRARY_PATH=/opt/mozjpeg/lib64:/opt/pngquant/lib:/opt/libtiff/lib

RUN set -ex \
    && python /usr/lib/python2.7/dist-packages/virtualenv.py /opt/thumbor \
    && /opt/thumbor/bin/pip install --disable-pip-version-check --upgrade pip

ENV THUMBOR_VERSION=6.7.0
RUN set -ex \
    && /opt/thumbor/bin/pip install --disable-pip-version-check thumbor==$THUMBOR_VERSION opencv-contrib-python-headless envparse \
    && /opt/thumbor/bin/pip install --disable-pip-version-check -I https://github.com/thumbor/thumbor-plugins/archive/master.zip

ARG SIMD_LEVEL=avx2
# workaround for https://github.com/python-pillow/Pillow/issues/3441
# https://github.com/thumbor/thumbor/issues/1102
RUN PILLOW_VERSION=$(/opt/thumbor/bin/python -c 'import PIL; print(PIL.__version__)') ; \
    if [ -z "$SIMD_LEVEL" ]; then \
      CC="cc" && PILLOW_PACKET="pillow" && PILLOW_VERSION_SUFFIX="" ;\
    else \
      CC="cc -m$SIMD_LEVEL" && PILLOW_PACKET="pillow-SIMD" && PILLOW_VERSION_SUFFIX=".post99" ;\
      # hardcoding to overcome https://github.com/MinimalCompact/thumbor/pull/37#issuecomment-514771902
      PILLOW_VERSION="5.2.0" ; \
    fi ; \

    /opt/thumbor/bin/pip uninstall -y pillow || true && \
    CC=$CC \
    CFLAGS="-I/opt/mozjpeg/include -I/opt/pngquant/include -I/opt/libtiff/include -I/usr/include/x86_64-linux-gnu" \
    LDFLAGS="-L/opt/mozjpeg/lib64 -L/opt/pngquant/lib -L/opt/libtiff/lib -L/usr/lib/x86_64-linux-gnu"  \
    /opt/thumbor/bin/pip install --no-cache-dir -U --force-reinstall --no-binary=:all: "${PILLOW_PACKET}<=${PILLOW_VERSION}${PILLOW_VERSION_SUFFIX}" \
    # --global-option="build_ext" --global-option="--debug" \
    --global-option="build_ext" --global-option="--enable-imagequant" \
    --global-option="build_ext" --global-option="--enable-jpeg" \
    --global-option="build_ext" --global-option="--enable-lcms" \
    --global-option="build_ext" --global-option="--enable-tiff" \
    --global-option="build_ext" --global-option="--enable-webp" \
    --global-option="build_ext" --global-option="--enable-zlib"

COPY docker/build-scripts /usr/local/docker/build-scripts

RUN DOCKERIZE_VERSION=1.3.0 /usr/local/docker/build-scripts/install-dockerize
RUN SUPERVISORD_VERSION=0.6.7 /usr/local/docker/build-scripts/install-supervisord

COPY src/presslabs /opt/thumbor/lib/python2.7/site-packages/presslabs

FROM nginx:1.16.1 as nginx

FROM scratch as deps
# thumbor deps
COPY --from=build-tools /opt /opt
COPY --from=build-venv /usr/local/bin /usr/local/bin
COPY --from=build-venv /lib/x86_64-linux-gnu/liblzma* /lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/libjbig* /usr/lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/liblcms2* /usr/lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/libpng* /usr/lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/libwebp* /usr/lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/libzstd* /usr/lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/libgthread* /usr/lib/x86_64-linux-gnu/
COPY --from=build-venv /usr/lib/x86_64-linux-gnu/libglib* /usr/lib/x86_64-linux-gnu/

# nginx
COPY --from=nginx /lib/x86_64-linux-gnu/libpcre* /lib/x86_64-linux-gnu/
COPY --from=nginx /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx /etc/nginx /etc/nginx
COPY --from=nginx /var/log/nginx /var/log/nginx

COPY docker/templates /etc/templates
COPY docker/docker-entrypoint /usr/local/bin/docker-entrypoint

COPY --from=build-venv /usr/bin/ldd /usr/bin/ldd

# Copy the virtualenv into a distroless image
FROM gcr.io/distroless/python2.7-debian10:debug

ENV PATH="/opt/thumbor/bin:/opt/mozjpeg/bin:/opt/pngquant/bin:/opt/libtiff/bin:/opt/gifsicle/bin:${PATH}"
ENV LD_LIBRARY_PATH=/opt/mozjpeg/lib64:/opt/pngquant/lib:/opt/libtiff/lib

COPY --from=deps / /
COPY --from=build-venv /opt/thumbor /opt/thumbor

USER nonroot
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
CMD ["supervisord", "init", "-c", "/tmp/etc/supervisor.conf"]
