FROM alpine:edge AS wsdd2-builder

RUN apk add --no-cache make gcc libc-dev linux-headers && wget -O - https://github.com/Netgear/wsdd2/archive/refs/heads/master.tar.gz | tar zxvf - \
 && cd wsdd2-master && sed -i 's/-O0/-O0 -Wno-int-conversion/g' Makefile && make

# Build renameat2 shim: provides the symbol for kernels that expose
# renameat2 only via syscall but not yet via glibc symbol
FROM alpine:edge AS renameat2-shim-builder
RUN apk add --no-cache gcc libc-dev
RUN cat > /renameat2_shim.c << 'EOF'
#define _GNU_SOURCE
#include <fcntl.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <errno.h>

#ifndef SYS_renameat2
# if defined(__x86_64__)
#  define SYS_renameat2 316
# elif defined(__aarch64__)
#  define SYS_renameat2 276
# elif defined(__arm__)
#  define SYS_renameat2 382
# else
#  define SYS_renameat2 -1
# endif
#endif

int renameat2(int olddirfd, const char *oldpath,
              int newdirfd, const char *newpath,
              unsigned int flags)
{
    if (SYS_renameat2 == -1) { errno = ENOSYS; return -1; }
    long ret = syscall(SYS_renameat2, olddirfd, oldpath, newdirfd, newpath, (long)flags);
    if (ret < 0) { errno = -ret; return -1; }
    return (int)ret;
}
EOF
RUN gcc -shared -fPIC -nostartfiles -o /librenameat2_shim.so /renameat2_shim.c

FROM alpine:edge

COPY --from=wsdd2-builder /wsdd2-master/wsdd2 /usr/sbin
COPY --from=renameat2-shim-builder /librenameat2_shim.so /usr/local/lib/librenameat2_shim.so

ENV PATH="/container/scripts:${PATH}"
# Preload the shim so smbd finds renameat2 even on older host kernels
ENV LD_PRELOAD="/usr/local/lib/librenameat2_shim.so"

RUN apk add --no-cache runit \
                       tzdata \
                       avahi \
                       samba \
                       openssl \
 \
 && sed -i 's/#enable-dbus=.*/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf \
 && rm -vf /etc/avahi/services/* \
 \
 && mkdir -p /external/avahi \
 && mkdir -p /etc/samba/tls \
 && touch /external/avahi/not-mounted \
 && echo done

VOLUME ["/shares"]

# Standard SMB ports + QUIC (UDP 443)
EXPOSE 137/udp 139 445 443/udp

COPY . /container/

HEALTHCHECK CMD ["/container/scripts/docker-healthcheck.sh"]
ENTRYPOINT ["/container/scripts/entrypoint.sh"]

CMD [ "runsvdir","-P", "/container/config/runit" ]
