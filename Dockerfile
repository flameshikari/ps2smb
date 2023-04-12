FROM alpine:3.13.5
RUN apk add --no-cache samba-server=4.13.8 samba-common-tools=4.13.8 openssl
COPY smb.conf /etc/samba/smb.conf
CMD smbd --foreground --no-process-group --debug-stdout
