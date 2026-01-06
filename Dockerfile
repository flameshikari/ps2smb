FROM alpine:latest AS ghfs
ARG TARGETARCH
ARG VERSION=1.21.1
WORKDIR /tmp
RUN << EOF
apk add --no-cache curl tar
curl -L "https://github.com/mjpclab/go-http-file-server/releases/download/v${VERSION}/ghfs-${VERSION}-linux-${TARGETARCH}.tar.gz" | tar -xzf - \
EOF

FROM ghcr.io/ironpeakservices/iron-alpine/iron-alpine:3.14.0

RUN apk add --no-cache openssl samba-common-tools samba-server

ARG USER=opl
ARG PASS=opl
ARG WORKDIR=/mnt/opl
ARG NETBIOS_PORT=1139
ARG SMB_PORT=1445
ARG GHFS_PORT=8080
ARG APP_USER=app

RUN << EOF
PASS_STDIN="${PASS}\n${PASS}"

adduser -H -D -s /bin/ash -u 2000 ${USER}

echo -e "${PASS_STDIN}" | passwd ${USER}
echo -e "${PASS_STDIN}" | smbpasswd -a -s ${USER}

cat << CONF > /etc/samba/smb.conf
[global]
    log level = 3
    workgroup = WORKGROUP
    server string = PS2 Samba Server
    server role = standalone server
    log file = /dev/stdout
    max log size = 0

    load printers = no
    printing = bsd
    printcap name = /etc/printcap
    printcap cache time = 0
    disable spoolss = yes

    smb ports = ${SMB_PORT} ${NETBIOS_PORT} 

    pam password change = yes
    map to guest = bad user
    usershare allow guests = yes
    create mask = 0664
    force create mode = 0664
    directory mask = 0775
    force directory mode = 0775
    force user = ${USER}
    force group = ${USER}

    server min protocol = NT1
    server signing = disabled
    smb encrypt = disabled
    ntlm auth = yes

    socket options = TCP_NODELAY TCP_KEEPIDLE=20 IPTOS_LOWDELAY SO_KEEPALIVE

    keepalive = 0

    getwd cache = yes
    large readwrite = yes
    aio read size = 0
    aio write size = 0
    strict locking = no

    strict sync = no
    strict allocate = no
    read raw = no
    write raw = no

    follow symlinks = yes

[opl]
    comment = PlayStation 2
    path = ${WORKDIR}
    browsable = yes
    guest ok = yes
    public = yes
    available = yes
    read only = no
    veto files = /._*/.apdisk/.AppleDouble/.DS_Store/.TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/Network Trash Folder/Temporary Items/Thumbs.db/
    delete veto files = yes
CONF

chown ${APP_USER}:${APP_USER} -R \
    /etc/samba \
    /run/samba \
    /var/cache/samba \
    /var/lib/samba \
    /var/log/samba
EOF

RUN /app/post-install.sh

COPY --from=ghfs /tmp/ghfs /bin/ghfs

USER ${APP_USER}
EXPOSE ${NETBIOS_PORT} ${SMB_PORT}
WORKDIR ${WORKDIR}
CMD ghfs --hostname OPL -l 0.0.0.0:8080 -r /mnt/opl --global-upload --global-mkdir --global-delete --global-auth --user opl:opl & \
    smbd --foreground --no-process-group --log-stdout