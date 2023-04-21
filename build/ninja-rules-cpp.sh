#!/usr/bin/env bash
#
# Actions invoked by build.ninja, which is generated by ./NINJA-config.sh.
#
# It's distributed with the tarball and invoked by _build/oils.sh, so
# it's written in a /bin/sh style.  But we're not using /bin/sh yet.
#
# And some non-Ninja wrappers.
#
# Usage:
#   build/ninja-rules-cpp.sh <function name>
#
# Env variables:
#   CXXFLAGS= - additional flags
#   OIL_NINJA_VERBOSE=1 - show command lines
#   TIME_TSV_OUT=file - compile_one and link output rows to this TSV file

set -o nounset
set -o errexit
# For /bin/sh portability
#eval 'set -o pipefail'

REPO_ROOT=$(cd "$(dirname $0)/.."; pwd)

. build/common.sh  # for $BASE_CXXFLAGS

# for HAVE_READLINE
if ! . _build/detected-config.sh; then
  die "Can't find _build/detected-config.sh.  Run './configure'"
fi

line_count() {
  local out=$1
  shift  # rest are inputs
  wc -l "$@" | sort -n | tee $out
}

#
# Mutable GLOBALS
#

cxx=''         # compiler
flags=''       # compile flags
link_flags=''  # link flags

#
# Functions to set them
#

setglobal_cxx() {
  local compiler=$1

  case $compiler in 
    (cxx)   cxx='c++'    ;;
    (clang) cxx=$CLANGXX ;;
    (*)     die "Invalid compiler $compiler" ;;
  esac
}

setglobal_compile_flags() {
  ### Set flags based on $variant $more_cxx_flags and $dotd

  local variant=$1
  local more_cxx_flags=$2
  local dotd=${3:-}

  # flags from Ninja/shell respected
  flags="$BASE_CXXFLAGS -I $REPO_ROOT $more_cxx_flags"

  # flags from env respected
  local env_flags=${CXXFLAGS:-}
  if test -n "$env_flags"; then
    flags="$flags $env_flags"
  fi

  case $variant in
    *+bumpleak|*+bumproot|*+cheney)
      ;;
    *)
      flags="$flags -D MARK_SWEEP"
      ;;
  esac

  #log "FLAGS $flags"

  # Take care of config that affects ALL translation units
  case $variant in
    dbg*)
      flags="$flags -O0 -g"
      ;;
    dbg32*)
      flags="$flags -O0 -g -m32"
      ;;

    asan*)
      flags="$flags -O0 -g -fsanitize=address"
      ;;
    asan32*)
      flags="$flags -O0 -g -fsanitize=address -m32"
      ;;

    tsan*)
      flags="$flags -O0 -g -fsanitize=thread"
      ;;

    ubsan*)
      # faster build with -O0
      flags="$flags -O0 -g -fsanitize=undefined"
      ;;

    opt*)
      flags="$flags -O2 -g -D OPTIMIZED"
      ;;
    opt32*)
      flags="$flags -O2 -g -D OPTIMIZED -m32"
      ;;

    coverage*)
      # source-based coverage is more precise than say sanitizer-based
      # https://clang.llvm.org/docs/SourceBasedCodeCoverage.html
      flags="$flags -O0 -g -fprofile-instr-generate -fcoverage-mapping"
      ;;

    uftrace*)
      # -O0 creates a A LOT more data.  But sometimes we want to see the
      # structure of the code.
      # NewStr(), OverAllocatedStr(), StrFromC() etc. are not inlined
      # Ditto vector::size(), std::forward, len(), etc.

      local opt='-O0'
      #local opt='-O2'
      flags="$flags $opt -g -pg"
      ;;

    (tcmalloc)
      flags="$flags -O2 -g -D TCMALLOC -D OPTIMIZED"
      ;;

    (*)
      die "Invalid variant $variant"
      ;;
  esac

  # Application variant

  case $variant in
    *+gcalways)
      flags="$flags -D GC_ALWAYS"
      ;;

    *+cheney)
      flags="$flags -D CHENEY_GC"
      ;;

    *+bumpleak)
      flags="$flags -D BUMP_LEAK"
      ;;
    *+bumproot)
      flags="$flags -D BUMP_LEAK -D BUMP_ROOT"
      ;;

    *+bumpbig)
      flags="$flags -D BUMP_ROOT -D BUMP_BIG"
      ;;
    *+bumpsmall)
      flags="$flags -D BUMP_ROOT -D BUMP_SMALL"
      ;;
  esac

  # needed to strip unused symbols
  # https://stackoverflow.com/questions/6687630/how-to-remove-unused-c-c-symbols-with-gcc-and-ld

  # Note: -ftlo doesn't do anything for size?

  flags="$flags -fdata-sections -ffunction-sections"

  # https://ninja-build.org/manual.html#ref_headers
  if test -n "$dotd"; then
    flags="$flags -MD -MF $dotd"
  fi
}

setglobal_link_flags() {
  local variant=$1

  case $variant in
    dbg32*|opt32*)
      link_flags='-m32'
      ;;

    # Must REPEAT these flags, otherwise we lose sanitizers / coverage
    asan*)
      link_flags='-fsanitize=address'
      ;;
    asan32*)
      link_flags='-fsanitize=address -m32'
      ;;

    tcmalloc)
      # Need to tell the dynamic loader where to find tcmalloc
      link_flags='-ltcmalloc -Wl,-rpath,/usr/local/lib'
      ;;

    tsan)
      link_flags='-fsanitize=thread'
      ;;
    ubsan*)
      link_flags='-fsanitize=undefined'
      ;;
    coverage)
      link_flags='-fprofile-instr-generate -fcoverage-mapping'
      ;;
  esac

  case $variant in
    # TODO: 32-bit variants can't handle -l readline right now.
    dbg32*|opt32*|asan32*)
      ;;

    *)
      if test "$HAVE_READLINE" = 1; then
        link_flags="$link_flags -lreadline"
      fi
      ;;
  esac

  link_flags="$link_flags -Wl,--gc-sections"
}

compile_one() {
  ### Compile one translation unit.  Invoked by build.ninja

  local compiler=$1
  local variant=$2
  local more_cxx_flags=$3
  local in=$4
  local out=$5
  local dotd=${6:-}  # optional .d file

  setglobal_compile_flags "$variant" "$more_cxx_flags" "$dotd"

  case $out in
    (_build/preprocessed/*)
      flags="$flags -E"
      ;;

	 # DISABLE spew for mycpp-generated code.  mycpp/pea could flag this at the
   # PYTHON level, rather than doing it at the C++ level.
   (_build/obj/*/_gen/bin/oils_for_unix.mycpp.o)
     flags="$flags -Wno-unused-variable -Wno-unused-but-set-variable"
     ;;
  esac

  # TODO: exactly when is -fPIC needed?  Clang needs it sometimes?
  if test $compiler = 'clang' && test $variant != 'opt'; then
    flags="$flags -fPIC"
  fi

  # this flag is only valid in Clang, doesn't work in continuous build
  if test "$compiler" = 'clang'; then
    flags="$flags -ferror-limit=10"
  fi

  setglobal_cxx $compiler

  if test -n "${OIL_NINJA_VERBOSE:-}"; then
    echo '__' "$cxx" $flags -o "$out" -c "$in" >&2
  fi

  # Not using arrays because this is POSIX shell
  local prefix=''
  if test -n "${TIME_TSV_OUT:-}"; then
    prefix="benchmarks/time_.py --tsv --out $TIME_TSV_OUT --append --rusage --field compile_one --field $out --"
  fi

  $prefix "$cxx" $flags -o "$out" -c "$in"
}

link() {
  ### Link a binary.  Invoked by build.ninja

  local compiler=$1
  local variant=$2
  local out=$3
  shift 3
  # rest are inputs

  setglobal_link_flags $variant

  setglobal_cxx $compiler

  local prefix=''
  if test -n "${TIME_TSV_OUT:-}"; then
    prefix="benchmarks/time_.py --tsv --out $TIME_TSV_OUT --append --rusage --field link --field $out --"
  fi

  # IMPORTANT: Flags like -ltcmalloc have to come AFTER objects!  Weird but
  # true.
  $prefix "$cxx" -o "$out" "$@" $link_flags
}

compile_and_link() {
  ### This function is no longer used; use 'compile_one' and 'link'

  local compiler=$1
  local variant=$2
  local more_cxx_flags=$3
  local out=$4
  shift 4

  setglobal_compile_flags "$variant" "$more_cxx_flags" ""  # no dotd

  setglobal_link_flags $variant

  setglobal_cxx $compiler

  if test -n "${OIL_NINJA_VERBOSE:-}"; then
    echo "__ $cxx -o $out $flags $@ $link_flags" >&2
  fi

  "$cxx" -o "$out" $flags "$@" $link_flags
}

strip_() {
  ### Invoked by ninja

  local in=$1
  local stripped=$2
  local symbols=${3:-}

  strip -o $stripped $in

  if test -n "$symbols"; then
    objcopy --only-keep-debug $in $symbols
    objcopy --add-gnu-debuglink=$symbols $stripped
  fi
}

symlink() {
  local dir=$1
  local in=$2
  local out=$3

  cd $dir
  ln -s -f -v $in $out
}

# test/cpp-unit.sh sources this
if test $(basename $0) = 'ninja-rules-cpp.sh'; then
  "$@"
fi
