FROM debian:buster as builder

ENV MOZJPEG_VERSION=v3.3.1
ENV PNGQUANT_VERSION=2.12.6

WORKDIR /usr/src

RUN set -ex \
    && apt update && apt install --no-install-recommends -y \
        build-essential autoconf automake libtool pkg-config nasm git \
        ca-certificates libpng-dev

RUN set -ex \
    && git clone https://github.com/mozilla/mozjpeg.git \
    && cd mozjpeg \
    && git checkout ${MOZJPEG_VERSION}

WORKDIR /usr/src/mozjpeg
RUN set -ex \
    && autoreconf -fiv \
    && ./configure \
    && make \
    && make install

WORKDIR /usr/src
RUN set -ex \
    && git clone https://github.com/kornelski/pngquant \
    && cd pngquant \
    && git checkout ${PNGQUANT_VERSION}

WORKDIR /usr/src/pngquant
RUN set -ex \
    && ./configure --prefix=/opt/pngquant \
    && make \
    && make install

FROM debian:buster

COPY --from=builder /opt/mozjpeg /opt/mozjpeg
COPY --from=builder /opt/pngquant /opt/pngquant

ENV THUMBOR_VERSION=6.7.0
ENV DOCKERIZE_VERSION=1.3.0

RUN apt update && apt install --no-install-recommends -y \
       gcc curl python-virtualenv libcurl4-openssl-dev python-dev libssl-dev libglib2.0-0 \
    && python /usr/lib/python2.7/dist-packages/virtualenv.py /opt/thumbor \
    && /opt/thumbor/bin/pip install thumbor==$THUMBOR_VERSION opencv-contrib-python==3.3.0.9 \
    && apt-get autoremove --purge -y libcurl4-openssl-dev python-dev libssl-dev

COPY ./docker /usr/local/docker

RUN /usr/local/docker/build-scripts/install-dockerize

COPY docker-entrypoint.sh /

ENTRYPOINT ["./docker-entrypoint.sh"]
