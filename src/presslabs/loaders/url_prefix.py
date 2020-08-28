#!/usr/bin/python
# -*- coding: utf-8 -*-

# thumbor imaging service
# https://github.com/thumbor/thumbor/wiki

# Licensed under the MIT license:
# http://www.opensource.org/licenses/mit-license
# Copyright (c) 2011 globo.com thumbor@googlegroups.com

import os

from thumbor.loaders import http_loader
from tornado.concurrent import return_future

DEFAULT_URL_PREFIX = "http://localhost"


def _remove_prefix(prefix, s):
    if s.startswith(prefix):
        return s[len(prefix) :]
    return s


def _normalize_url(url):
    prefix = os.environ.get("THUMBOR_URL_PREFIX") or DEFAULT_URL_PREFIX
    path_prefix = os.environ.get("THUMBOR_URL_PREFIX_PATH", "")
    if path_prefix:
        url = "%s/%s" % (prefix, url) if url.startswith(path_prefix) else url
    url = http_loader.quote_url(url)

    # some proxies might remove the double slash so we check the
    # scheme using single slash
    scheme = "https" if url.startswith("https:/") else "http"

    # normalize the url scheme for proxies removing double slashes
    url = _remove_prefix("http:/", url)
    url = _remove_prefix("https:/", url)

    url = scheme + "://" + _remove_prefix("/", url)

    return url


def validate(context, url):
    return http_loader.validate(context, url, normalize_url_func=_normalize_url)


def return_contents(response, url, callback, context):
    return http_loader.return_contents(response, url, callback, context)


@return_future
def load(context, url, callback):
    return http_loader.load_sync(
        context, url, callback, normalize_url_func=_normalize_url
    )


def encode(string):
    return http_loader.encode(string)
