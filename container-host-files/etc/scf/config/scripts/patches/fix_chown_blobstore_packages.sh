set -e

PATCH_DIR="/var/vcap/jobs-src/blobstore/templates"
SENTINEL="${PATCH_DIR}/${0##*/}.sentinel"

if [ -f "${SENTINEL}" ]; then
  exit 0
fi

patch -d "$PATCH_DIR" --force -p0 <<'PATCH'
--- pre-start.sh.erb
+++ pre-start.sh.erb
@@ -9,7 +9,7 @@ function setup_blobstore_directories {
   local data_dir=/var/vcap/data/blobstore
   local store_tmp_dir=$store_dir/tmp/uploads
   local data_tmp_dir=$data_dir/tmp/uploads
-  local nginx_webdav_dir=/var/vcap/packages/nginx_webdav
+  local packages_dir=/var/vcap/packages
 
   mkdir -p $run_dir
   mkdir -p $log_dir
@@ -18,7 +18,7 @@ function setup_blobstore_directories {
   mkdir -p $data_dir
   mkdir -p $data_tmp_dir
 
-  local dirs="$run_dir $log_dir $store_dir $store_tmp_dir $data_dir $data_tmp_dir $nginx_webdav_dir ${nginx_webdav_dir}/.."
+  local dirs="$run_dir $log_dir $store_dir $store_tmp_dir $data_dir $data_tmp_dir $packages_dir"
   local num_needing_chown=$(find $dirs -not -user vcap -or -not -group vcap | wc -l)
 
   if [ $num_needing_chown -gt 0 ]; then
PATCH

touch "${SENTINEL}"

exit 0
