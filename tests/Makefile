PACT=pact

MODULES = policy-extra-donation \
          policy-extra-currency-whitelist \
					policy-extra-lottery \
					policy-extra-multi-sellers

all: tests


.modules:
	mkdir -p .modules

.modules/%: ../pact/% | .modules
	m4 -I../pact -D__MARMALADE_NG_NS__=marmalade-ng $< > $@

modules: $(addprefix .modules/, $(addsuffix .pact, ${MODULES}))

tests: modules
	@echo "============== policy-extra-donation ==============="
	${PACT} test-policy-extra-donation.repl
	@echo "============== policy-extra-currency-whitelist ==============="
	${PACT} test-policy-extra-currency-whitelist.repl
	@echo "============== policy-extra-lottery ==============="
	${PACT} test-policy-extra-lottery.repl
	@echo "============== policy-extra-multi-sellers ==============="
	${PACT} test-policy-extra-multi-sellers.repl
	@echo "============== TYPECHECKER ==============="
	${PACT} typecheck.repl

clean:
	rm -rf .modules
