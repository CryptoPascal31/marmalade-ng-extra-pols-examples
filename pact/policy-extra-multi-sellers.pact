(module policy-extra-multi-sellers GOVERNANCE
  (implements __MARMALADE_NG_NS__.token-policy-ng-v1)
  (use __MARMALADE_NG_NS__.token-policy-ng-v1 [token-info])
  (use __MARMALADE_NG_NS__.ledger [escrow])
  (use __MARMALADE_NG_NS__.policy-extra-policies)
  (use __MARMALADE_NG_NS__.util-policies)
  (use free.util-strings)
  (use free.util-lists)
  (use free.util-math)


  ;-----------------------------------------------------------------------------
  ; Governance
  ;-----------------------------------------------------------------------------
  (defconst ADMIN-KEYSET:string (read-string "admin_keyset"))
  (defcap GOVERNANCE ()
   (enforce-keyset ADMIN-KEYSET))

  ;-----------------------------------------------------------------------------
  ; Tables and schema
  ;-----------------------------------------------------------------------------
  ; Same schema is used for guards creation and storage in database
  (defschema multi-sellers-sch
    dest-accounts:[string]
    currency: module{fungible-v2}
  )

  (deftable sales:{multi-sellers-sch})

  ;-----------------------------------------------------------------------------
  ; Capabilities and events
  ;-----------------------------------------------------------------------------
  (defcap MULTI-SELLERS-OFFER (accounts:[string])
    @event
    true
  )

  ;-----------------------------------------------------------------------------
  ; Input data
  ;-----------------------------------------------------------------------------
  (defschema multi-sellers-msg-sch
    accounts:[string]
  )


  (defun read-multi-sellers-msg:object{multi-sellers-msg-sch} (token:object{token-info})
    (get-msg-data "multi_sellers" token {'accounts:[]}))

  ;-----------------------------------------------------------------------------
  ; Util functions
  ;-----------------------------------------------------------------------------
  (defun is-sale-registered:bool ()
    (with-default-read sales (pact-id) {'dest-accounts:[]} {'dest-accounts:=accts}
      (is-not-empty accts))
  )

  ;-----------------------------------------------------------------------------
  ; Policy hooks
  ;-----------------------------------------------------------------------------
  ; Just before the sale
  (defun rank:integer ()
    (- RANK-SALE 1))

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
    (require-capability (POLICY-ENFORCE-OFFER token (pact-id) policy-extra-multi-sellers))
    (bind (read-multi-sellers-msg token) {'accounts:=accounts}
      (if (is-empty accounts)
          false
          (bind (enforce-read-sale-msg token) {'currency:=currency}
            (map (check-fungible-account currency) accounts)
            (insert sales (pact-id) {'dest-accounts:accounts, 'currency:currency})
            (emit-event (MULTI-SELLERS-OFFER accounts))
            false)))
  )

  (defun enforce-sale-withdraw:bool (token:object{token-info})
    true)

  (defun enforce-sale-buy:bool (token:object{token-info} buyer:string)
    true)

  (defun --enforce-sale-settle:bool (token:object{token-info})
    (require-capability (POLICY-ENFORCE-SETTLE token (pact-id) policy-extra-multi-sellers))
    (with-read sales (pact-id) {'dest-accounts:=accounts,
                                'currency:=currency:module{fungible-v2}}

        (let* ((escrow (escrow))
               (total-balance (currency::get-balance escrow))
               (to-pay (floor (/ total-balance (dec (++ (length accounts))))
                              (currency::precision))))
          (map (lambda (x) (install-capability (currency::TRANSFER escrow x total-balance)))
                accounts)
          (map (lambda (x) (currency::transfer escrow x to-pay))
               accounts)
          true))
    )

    (defun enforce-sale-settle:bool (token:object{token-info})
      (if (is-sale-registered)
          (--enforce-sale-settle token)
          false)
    )
)
