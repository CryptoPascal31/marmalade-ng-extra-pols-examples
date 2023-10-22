#!/bin/bash
PACT="${PACT_BIN:-pact}"

case $1 in
"--short")
  POSTPROCESS="tail -1";;
*)
  POSTPROCESS="cat";;
esac

REPL_SCRIPTS="./test-policy-extra-currency-whitelist.repl
              ./test-policy-extra-donation.repl
              ./test-policy-extra-lottery.repl
              ./test-policy-extra-multi-sellers.repl "

for repl in $REPL_SCRIPTS
  do echo "============================================================"
     echo "Running $repl"
     echo "============================================================"
     ${PACT} $repl 2>&1 | $POSTPROCESS
     echo ""
done
