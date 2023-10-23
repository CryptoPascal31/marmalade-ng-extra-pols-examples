(namespace "__NAMESPACE__")

include(policy-extra-multi-sellers.pact)dnl
"Module loaded"
ifdef(`__INIT__',dnl
(create-table sales)
)
