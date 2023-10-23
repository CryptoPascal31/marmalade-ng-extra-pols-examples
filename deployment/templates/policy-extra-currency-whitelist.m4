(namespace "__NAMESPACE__")

include(policy-extra-currency-whitelist.pact)dnl
"Module loaded"
ifdef(`__INIT__',dnl
(create-table whitelists)
)
