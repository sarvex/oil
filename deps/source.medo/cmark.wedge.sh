# Wedge definition for cmark
#
# Loaded by deps/wedge.sh.

set -o nounset
set -o pipefail
set -o errexit

# sourced
WEDGE_NAME='cmark'
WEDGE_VERSION='0.29.0'

wedge-build() {
  local src_dir=$1
  local build_dir=$2
  local install_dir=$3

  pushd $build_dir

  time cmake -DCMAKE_INSTALL_PREFIX=$install_dir $src_dir

  time make

  # make test

  popd
}

wedge-install() {
  local build_dir=$1

  pushd $build_dir

  time make install

  popd
}

wedge-smoke-test() {
  local install_dir=$1

  ldd $install_dir/lib/libcmark.so.$WEDGE_VERSION
}
