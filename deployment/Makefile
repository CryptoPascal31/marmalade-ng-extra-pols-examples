NAMESPACE = "n_b402dc44ff03a3bae3b434f25c1802297026f6b3"
NG_NAMESPACE = "n_442d3e11cfe0d39859878e5b1520cd8b8c36e5db"

DATA_FILE = testnet_data.yaml

KEY_FILES = keys/gas-payer.yaml \
            keys/extra-admin.yaml \
						keys/extra-ns.yaml

INIT=-D__INIT__

TRANSACTION_FILES = policy-extra-donation \
                    policy-extra-currency-whitelist \
										policy-extra-lottery  \
										policy-extra-multi-sellers

.PRECIOUS: %.yaml .pact/%.pact


all: $(addsuffix .json, ${TRANSACTION_FILES})

.pact:
	mkdir -p .pact

%.json: %.yaml
	$(foreach kf,$(KEY_FILES),kda sign $< -k ${kf};)

.pact/%.pact: templates/%.m4 | .pact
	m4 -I../pact -D__MARMALADE_NG_NS__=${NG_NAMESPACE} -D__NAMESPACE__=${NAMESPACE} -D__KIP_NAMESPACE__=${KIP_NAMESPACE} ${INIT} $< > $@

%.yaml: templates/%.tkpl .pact/%.pact
	kda gen -t $< -o $*.yaml -d ${DATA_FILE}

clean:
		rm -rf .pact
		rm -f *.json
		find . -maxdepth 1 -name "*.yaml" |grep -v "_data.yaml" | xargs rm -f
