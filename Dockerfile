FROM debian:buster

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
