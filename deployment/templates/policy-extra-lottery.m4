(namespace "__NAMESPACE__")

include(policy-extra-lottery.pact)dnl
"Module loaded"
ifdef(`__INIT__',dnl
(create-table sales)
)
