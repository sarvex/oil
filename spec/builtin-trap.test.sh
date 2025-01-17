# builtin-trap.test.sh

#### trap accepts/ignores --
trap -- 'echo hi' EXIT
echo done
## STDOUT:
done
hi
## END

#### trap 'echo hi' KILL (regression test, caught by smoosh suite)
trap 'echo hi' 9
echo status=$?
trap 'echo hi' KILL
echo status=$?
trap 'echo hi' STOP
echo status=$?
trap 'echo hi' TERM
echo status=$?
## STDOUT:
status=0
status=0
status=0
status=0
## END
## OK osh STDOUT:
status=1
status=1
status=1
status=0
## END

#### Register invalid trap
trap 'foo' SIGINVALID
## status: 1

#### Remove invalid trap
trap - SIGINVALID
## status: 1

#### SIGINT and INT are aliases
trap - SIGINT
echo $?
trap - INT
echo $?
## STDOUT:
0
0
## END
## N-I dash STDOUT:
1
0
## END

#### Invalid trap invocation
trap 'foo'
echo status=$?
## stdout: status=2
## OK dash stdout: status=1
## BUG mksh stdout: status=0

#### exit 1 when trap code string is invalid
# All shells spew warnings to stderr, but don't actually exit!  Bad!
trap 'echo <' EXIT
echo status=$?
## stdout: status=1
## BUG mksh status: 1
## BUG mksh stdout: status=0
## BUG dash/bash status: 0
## BUG dash/bash stdout: status=0

#### trap EXIT calling exit
cleanup() {
  echo "cleanup [$@]"
  exit 42
}
trap 'cleanup x y z' EXIT
## stdout: cleanup [x y z]
## status: 42

#### trap EXIT return status ignored
cleanup() {
  echo "cleanup [$@]"
  return 42
}
trap 'cleanup x y z' EXIT
## stdout: cleanup [x y z]
## status: 0

#### trap EXIT with PARSE error
trap 'echo FAILED' EXIT
for
## stdout: FAILED
## status: 2
## OK mksh status: 1

#### trap EXIT with PARSE error and explicit exit
trap 'echo FAILED; exit 0' EXIT
for
## stdout: FAILED
## status: 0

#### trap EXIT with explicit exit
trap 'echo IN TRAP; echo $stdout' EXIT 
stdout=FOO
exit 42

## status: 42
## STDOUT:
IN TRAP
FOO
## END

#### trap EXIT with command sub / subshell / pipeline
trap 'echo EXIT TRAP' EXIT 

echo $(echo command sub)

( echo subshell )

echo pipeline | cat

## STDOUT:
command sub
subshell
pipeline
EXIT TRAP
## END

#### trap ERR
err() {
  echo "err [$@] $?"
}
trap 'err x y' ERR 

echo A

false
echo B

( exit 42 )
echo C

trap - ERR  # disable trap

false
echo D

trap 'echo after errexit $?' ERR 

set -o errexit

( exit 99 )
echo E

## status: 99
## STDOUT:
A
err [x y] 1
B
err [x y] 42
C
D
after errexit 99
## END
## N-I dash STDOUT:
A
B
C
D
## END

#### trap ERR and pipelines (lastpipe and PIPESTATUS difference)
case $SH in dash) exit ;; esac

err() {
  echo "err [$@] status=$? [${PIPESTATUS[@]}]"
}
trap 'err' ERR 

echo A

false

# succeeds
echo B | grep B

# fails
echo C | grep zzz

echo D | grep zzz | cat

set -o pipefail
echo E | grep zzz | cat

trap - ERR  # disable trap

echo F | grep zz
echo ok

## STDOUT:
A
err [] status=1 [1]
B
err [] status=1 [0 1]
err [] status=1 [0 1 0]
ok
## END

# lastpipe semantics mean we get another call!
# also we don't set PIPESTATUS unless we get a pipeline

## OK osh STDOUT:
A
err [] status=1 []
B
err [] status=1 [0 0]
err [] status=1 [0 1]
err [] status=1 [0 1 0]
ok
## END

## N-I dash STDOUT:
## END

#### error in trap ERR (recursive)
case $SH in dash) exit ;; esac

err() {
  echo err status $?
  ( exit 2 )
}
trap 'err' ERR 

echo A
false
echo B

## STDOUT:
A
err status 1
B
## END
## N-I dash STDOUT:
## END

#### trap 0 is equivalent to EXIT
# not sure why this is, but POSIX wants it.
trap 'echo EXIT' 0
echo status=$?
trap - EXIT
echo status=$?
## status: 0
## STDOUT:
status=0
status=0
## END

#### trap 1 is equivalent to SIGHUP; HUP is equivalent to SIGHUP
trap 'echo HUP' SIGHUP
echo status=$?
trap 'echo HUP' HUP
echo status=$?
trap 'echo HUP' 1
echo status=$?
trap - HUP
echo status=$?
## status: 0
## STDOUT:
status=0
status=0
status=0
status=0
## END
## N-I dash STDOUT:
status=1
status=0
status=0
status=0
## END

#### eval in the exit trap (regression for issue #293)
trap 'eval "echo hi"' 0
## STDOUT:
hi
## END


#### exit codes for traps are isolated

trap 'echo USR1 trap status=$?; ( exit 42 )' USR1

echo before=$?

# Equivalent to 'kill -USR1 $$' except OSH doesn't have "kill" yet.
# /bin/kill doesn't exist on Debian unless 'procps' is installed.
sh -c "kill -USR1 $$"
echo after=$?

## STDOUT:
before=0
USR1 trap status=0
after=0
## END

#### traps are cleared in subshell (started with &)

# bash is FLAKY on CI for some reason.  dash/mksh are enough for us to test
# against.
case $SH in bash) exit ;; esac

trap 'echo USR1' USR1

kill -USR1 $$

# Hm trap doesn't happen here
{ echo begin child; sleep 0.1; echo end child; } &
kill -USR1 $!
wait

echo done

## STDOUT:
USR1
begin child
end child
done
## END
## BUG bash STDOUT:
## END
