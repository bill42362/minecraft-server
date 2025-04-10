FROM alpine:3.21

RUN apk add --no-cache \
    bash \
    tar \
    # md5sum \
    findutils \
    coreutils

COPY scripts/backup.sh /scripts/backup.sh
RUN chmod +x /scripts/backup.sh

CMD ["/scripts/backup.sh"]
# Keep container running without executing backup script
# CMD ["tail", "-f", "/dev/null"]