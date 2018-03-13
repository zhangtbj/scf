#!/usr/bin/env bash

set -o errexit

PATCH_DIR=/var/vcap/jobs-src/consul/templates/consul
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
    exit 0
fi

patch -d "${PATCH_DIR}" --force -p5 <<'PATCH'
diff --git a/jobs/consul/templates/consul/agent.json.erb b/jobs/consul/templates/consul/agent.json.erb
index 04450aa..50dbbc2 100644
--- a/jobs/consul/templates/consul/agent.json.erb
+++ b/jobs/consul/templates/consul/agent.json.erb
@@ -1,11 +1,13 @@
 <%
   require 'json'
+  require 'digest'
 
   join_hosts = link('consul_servers').instances.collect { |server| server.address }
   cluster_size = join_hosts.size
   is_server = p('consul.server', true)
   client_addr = p('consul.client_addr', '0.0.0.0')
   agent_config = p('consul.agent_config', nil)
+  node_digest = Digest::SHA1.hexdigest(spec.id)
 
   ssl_ca = p("consul.ssl_ca", nil)
   ssl_cert = p("consul.ssl_cert", nil)
@@ -15,7 +17,7 @@
     data_dir: '/var/vcap/store/consul',
     ui: true,
     node_name: "#{spec.deployment}-#{name}-#{index}",
-    node_id: "#{spec.id}",
+    node_id: "#{sprintf("%s-%s-4%s-8%s-%s", node_digest[0..7], node_digest[8..11], node_digest[12..14], node_digest[15..17], node_digest[18..29])}",
     bind_addr: '0.0.0.0',
     client_addr: client_addr,
     advertise_addr: spec.ip,
PATCH

touch "${SENTINEL}"

exit 0
