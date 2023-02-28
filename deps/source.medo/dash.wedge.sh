# Wedge definition for dash
#
# Loaded by deps/wedge.sh.

set -o nounset
set -o pipefail
set -o errexit

# sourced
WEDGE_NAME='dash'
WEDGE_VERSION='0.5.10.2'

wedge-build() {
  local src_dir=$1
  local build_dir=$2
  local install_dir=$3

  pushd $build_dir

  time $src_dir/configure --prefix=$install_dir

  time make

  # make test

  popd
}

wedge-install() {
  local build_dir=$1

  pushd $build_dir

  time make install-strip

  popd
}

wedge-smoke-test() {
  local install_dir=$1

  $install_dir/bin/dash -c 'echo "hi from dash"'
}
