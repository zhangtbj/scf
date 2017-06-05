#!/bin/bash
# (re)Start one or more specific roles.
# Assume that everything else is already active.
set -e

if [ $# -lt 2 ]; then
    echo 1>&2 "Usage: $(basename "$0") <DIR_WITH_ENV_FILES> <ROLE_NAME> ?<EXTRA-DOCKER> ...?"
    exit 1
fi

if test -z "${HCF_FORCE_RUN:-}" -a "$(id -un)" != "ubuntu" -a "$(id -un)" != "vagrant" ; then
    printf "%bERROR%b: Aborting run on host, this breaks due to port issues\n" "\033[0;1;31m" "\033[0m" >&2
    exit 1
fi

setup_dir="$1"
role_name="$2"
shift 2

if [ ! -d "$setup_dir" ]; then
    echo 1>&2 "Config directory does not exist"
    exit 1
fi

# Check for the filter helper file created for us by either 'make run'
# or 'run-all-roles.sh'. If it is missing create it ourselves
ROOT=`readlink -f "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../../../"`
CLEAN=""

stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" run-role::${role_name} start

if test ! -f $ROOT/vagrant.json ; then
    ( cd $ROOT ; make/vagrant-setup-env )
    CLEAN="${CLEAN} $ROOT/vagrant.json"
fi

# Vagrant
# SELF    = PWD/container-host-files/opt/hcf/bin/list-roles.sh
# SELFDIR = PWD/container-host-files/opt/hcf/bin

SELFDIR="$(readlink -f "$(cd "$(dirname "$0")" && pwd)")"

stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" run-role::setup::${role_name} start
. "${SELFDIR}/common.sh"

HCF_RUN_STORE="${HCF_RUN_STORE:-$HOME/.run/store}"
HCF_RUN_LOG_DIRECTORY="${HCF_RUN_LOG_DIRECTORY:-$HOME/.run/log}"

store_dir=$HCF_RUN_STORE
log_dir=$HCF_RUN_LOG_DIRECTORY

load_all_roles

stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" run-role::setup::${role_name} done

# (Re)start the specified role
stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" run-role::docker::${role_name} start
handle_restart "$role_name" "${setup_dir}" "$@"
stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" run-role::docker::${role_name} done

rm -f $CLEAN

stampy ${ROOT}/scf_metrics.csv "${BASH_SOURCE[0]}" run-role::${role_name} done
