

#### oil usage

try {
  $SH --location-file foo.hay --location-start-line 42 -c 'echo ()' 2>err.txt
}

cat err.txt | grep -o '^foo.hay:42: Unexpected'

## STDOUT:
foo.hay:42: Unexpected
## END
