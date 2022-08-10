FROM alpine:latest
COPY entrypoint.sh /entrypoint.sh
RUN apk update && apk add curl jq
ENTRYPOINT ["/entrypoint.sh"]
