FROM alpine:latest
RUN apk add build-base ldc dub libpq-dev
COPY . /
RUN dub build

FROM alpine:latest
RUN apk add busybox-extras libpq ldc
COPY inetd.conf.template /etc/inetd.conf
COPY conn-file.txt /
COPY --from=0 /unctfd /
EXPOSE 1337
CMD inetd -f
