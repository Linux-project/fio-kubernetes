FROM alpine

RUN apk add fio bc bash coreutils curl perf sysstat --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community
