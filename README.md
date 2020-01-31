# docker-thumbor
Basic Thumbor container

It uses dockerize to allow certain customizations:
  * `INSTANCE_MAIN_DOMAIN`, `INSTANCE_CDN_DOMAIN` and `INSTANCE_DOMAINS` defines allowed domains
  * `THUMBOR_ALLOW_UNSAFE_URL` specify if the container serves unsecure urls
  * `THUMBOR_SECURITY_KEY` is the secret key used to validate the requests
