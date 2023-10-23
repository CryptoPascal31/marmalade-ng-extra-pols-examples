(module policy-extra-currency-whitelist GOVERNANCE
  (implements __MARMALADE_NG_NS__.token-policy-ng-v1)
  (use __MARMALADE_NG_NS__.token-policy-ng-v1 [token-info])
  (use __MARMALADE_NG_NS__.policy-extra-policies)
  (use __MARMALADE_NG_NS__.util-policies)
  (use free.util-strings)
  (use free.util-lists)

  ;-----------------------------------------------------------------------------
  ; Governance
  ;-----------------------------------------------------------------------------
  (defconst ADMIN-KEYSET:string (read-string "admin_keyset"))
  (defcap GOVERNANCE ()
   (enforce-keyset ADMIN-KEYSET))

  ;-----------------------------------------------------------------------------
  ; Tables and schema
  ;-----------------------------------------------------------------------------
  (defschema whitelist-sch
    token-id:string
    whitelist:[module{fungible-v2}]
  )

  (deftable whitelists:{whitelist-sch})

  (defconst WL-NULL:[module{fungible-v2}] [])

  ;-----------------------------------------------------------------------------
  ; Util functions
  ;-----------------------------------------------------------------------------

  ;-----------------------------------------------------------------------------
  ; Policy hooks
  ;-----------------------------------------------------------------------------
  ; Just after royalty
  (defun rank:integer ()
    RANK-HIGH-PRIORITY)

  (defun enforce-init:bool (token:object{token-info})
    (enforce false "Init not supported in extra policies")
  )

  (defun enforce-mint:bool (token:object{token-info} account:string amount:decimal)
    true)

  (defun enforce-burn:bool (token:object{token-info} account:string amount:decimal)
    true)

  (defun enforce-transfer:bool (token:object{token-info} sender:string receiver:string amount:decimal)
    true)

  (defun enforce-sale-offer:bool (token:object{token-info} seller:string amount:decimal timeout:time)
    (require-capability (POLICY-ENFORCE-OFFER token (pact-id) policy-extra-currency-whitelist))
      (bind (read-sale-msg token) {'currency:=currency}
        (with-default-read whitelists (at 'id token) {'whitelist:[]} {'whitelist:=whitelist}
          (enforce (or (is-empty whitelist)
                       (contains (to-string currency) (map (to-string) whitelist)))
                    "Currency not allowed")))
    false
  )

  (defun enforce-sale-withdraw:bool (token:object{token-info})
    true)

  (defun enforce-sale-buy:bool (token:object{token-info} buyer:string)
    true)

  (defun enforce-sale-settle:bool (token:object{token-info})
    true)

  (defun update-allowed-currencies:string (token-id:string currencies:[module{fungible-v2}])
    @doc "Change the list of allowed currencies"
    (enforce (is-not-empty currencies) "Currencies list can't be empty")
    (enforce-guard (get-guard-by-id token-id))
    (write whitelists token-id {'token-id:token-id, 'whitelist:currencies})
  )

  (defun allow-all-currencies:string (token-id:string)
    (enforce-guard (get-guard-by-id token-id))
    ; Empty whitelist means all allowed
    (write whitelists token-id {'token-id:token-id, 'whitelist:WL-NULL})
  )

)
