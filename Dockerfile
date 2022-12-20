FROM alpine:edge as builder
RUN apk add --update crystal shards yaml-dev musl-dev make
RUN mkdir /ameba
WORKDIR /ameba
COPY . /ameba/
RUN make clean && make

FROM alpine:latest
RUN apk add --update yaml pcre gc libevent libgcc
RUN mkdir /src
WORKDIR /src
COPY --from=builder /ameba/bin/ameba /usr/bin/
ENTRYPOINT [ "/usr/bin/ameba" ]
