#!/bin/bash
#
# Usage:
#   ./virtual-memory.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

source test/common.sh  # log

readonly BASE_DIR=_tmp/vm-baseline

# TODO: Call this from benchmarks/auto.sh.

vm-baseline() {
  local provenance=$1
  local base_dir=${2:-_tmp/vm-baseline}
  #local base_dir=${2:-../benchmark-data/vm-baseline}

  local name=$(basename $provenance)
  local prefix=${name%.provenance.txt}  # strip suffix

  local host=$(hostname)
  local out_dir="$base_dir/$prefix"
  mkdir -p $out_dir

  # Fourth column is the shell.
  cat $provenance | while read _ _ _ sh_path shell_hash; do
    local sh_name=$(basename $sh_path)

    # There is a race condition on the status but sleep helps.
    local out="$out_dir/${sh_name}-${shell_hash}.txt"
    $sh_path -c 'sleep 0.001; cat /proc/$$/status' > $out
  done

  echo
  echo "$out_dir:"
  ls -l $out_dir
}

# Run a single file through stage 1 and report.
demo() {
  local -a job_dirs=($BASE_DIR/lisa.2017-*)
  local dir1=$BASE_DIR/stage1
  local dir2=$BASE_DIR/stage2

  mkdir -p $dir1 $dir2
  
  benchmarks/virtual_memory.py baseline ${job_dirs[-1]} \
    > $dir1/vm-baseline.csv

  benchmarks/report.R vm-baseline $dir1 $dir2
}

# Combine CSV files.
stage1() {
  local raw_dir=${1:-$BASE_DIR/raw}
  local out=$BASE_DIR/stage1
  mkdir -p $out

  # Globs are in lexicographical order, which works for our dates.
  local -a m1=(../benchmark-data/vm-baseline/flanders.*)
  local -a m2=(../benchmark-data/vm-baseline/lisa.*)

  # The last one
  local -a latest=(${m1[-1]} ${m2[-1]})

  benchmarks/virtual_memory.py baseline "${latest[@]}" \
    | tee $out/vm-baseline.csv
}

# Demo of the --dump-proc-status-to flag.
# NOTE: Could also add Python introspection.
parser-dump-demo() {
  local out_dir=_tmp/virtual-memory
  mkdir -p $out_dir

  # VmRSS: 46 MB for abuild, 200 MB for configure!  That is bad.  This
  # benchmark really is necessary.
  local input=benchmarks/testdata/abuild

  bin/osh \
    --parser-mem-dump $out_dir/parser.txt -n --ast-format none \
    $input

  grep '^Vm' $out_dir/parser.txt
}

runtime-dump-demo() {
  # Multiple processes
  #OIL_TIMING=1 bin/osh -c 'echo $(echo hi)'

  local out_dir=_tmp/virtual-memory
  mkdir -p $out_dir
  bin/osh \
    --parser-mem-dump $out_dir/parser.txt \
    --runtime-mem-dump $out_dir/runtime.txt \
    -c 'echo $(echo hi)'

  grep '^Vm' $out_dir/parser.txt $out_dir/runtime.txt
}

"$@"
