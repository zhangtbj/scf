#!/usr/bin/env bash

set -o errexit

PATCH_DIR=/var/vcap/jobs-src/consul/templates/bin
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
    exit 0
fi

patch -d "${PATCH_DIR}" --force -p5 <<'PATCH'
diff --git a/jobs/consul/templates/bin/consul_ctl b/jobs/consul/templates/bin/consul_ctl
index fda2ecf..d596a6e 100644
--- a/jobs/consul/templates/bin/consul_ctl
+++ b/jobs/consul/templates/bin/consul_ctl
@@ -19,14 +19,6 @@ case $1 in
 
     setcap cap_net_bind_service=+ep $(readlink -nf /var/vcap/packages/consul/bin/consul)
 
-    <% if p("consul.resolvconf_override") == true %>
-    echo "nameserver 127.0.0.1" > /etc/resolv.conf
-    <% else %>
-    if ! grep -q 127.0.0.1 /etc/resolv.conf; then
-      sed -i -e '1i nameserver 127.0.0.1' /etc/resolv.conf
-    fi
-    <% end %>
-
     mkdir -p /var/vcap/data/consul
     chown <%= user %>:<%= user %> /var/vcap/data/consul
     config_dir="-config-dir /var/vcap/data/consul "
PATCH

touch "${SENTINEL}"

exit 0
