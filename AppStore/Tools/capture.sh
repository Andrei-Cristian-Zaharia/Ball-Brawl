#!/bin/bash
# capture.sh <udid> <lang> <locale> <outdir> [scenes...]
UDID=$1; LANG_CODE=$2; LOC=$3; OUT=$4; shift 4
SCENES=${@:-abilities daily collection arenas modes crusade}
B=com.andreizaharia.ballbrawl
mkdir -p "$OUT"
for sc in $SCENES; do
  xcrun simctl terminate $UDID $B >/dev/null 2>&1
  xcrun simctl launch $UDID $B -storeDemo $sc -AppleLanguages "($LANG_CODE)" -AppleLocale $LOC >/dev/null
  sleep 3.5
  xcrun simctl io $UDID screenshot "$OUT/$sc.png" >/dev/null 2>&1
done
xcrun simctl terminate $UDID $B >/dev/null 2>&1
