(namespace "__NAMESPACE__")

include(policy-extra-donation.pact)dnl
"Module loaded"
(__MARMALADE_NG_NS__.util-policies.check-fungible-account coin DONATION-ACCOUNT)
ifdef(`__INIT__',dnl
(create-table tokens)
(create-table sales)
)
