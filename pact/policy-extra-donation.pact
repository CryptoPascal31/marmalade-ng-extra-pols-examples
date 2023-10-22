(module policy-extra-donation GOVERNANCE
  (implements marmalade-ng.token-policy-ng-v1)
  (use marmalade-ng.token-policy-ng-v1 [token-info])
  (use marmalade-ng.ledger [escrow])
  (use marmalade-ng.policy-extra-policies)
  (use marmalade-ng.util-policies)
  (use free.util-strings)

  ;-----------------------------------------------------------------------------
  ; Governance
  ;-----------------------------------------------------------------------------
  (defconst ADMIN-KEYSET:string (read-string "extra_examples_keyset"))
  (defcap GOVERNANCE ()
   (enforce-keyset ADMIN-KEYSET))

  ;-----------------------------------------------------------------------------
  ; Tables and schema
  ;-----------------------------------------------------------------------------
  ; Same schema is used for guards creation and storage in database
  (defschema bool-sch
    enabled:bool
  )

  (deftable tokens:{bool-sch})
  (deftable sales:{bool-sch})

  ;-----------------------------------------------------------------------------
  ; Constants
  ;-----------------------------------------------------------------------------
  (defconst DONATION-ACCOUNT:string (read-string 'donation_account))
  (defconst DONATION-AMOUNT:decimal 0.1)
  (defconst SALE-MINIMUM:decimal 0.2)

  ;-----------------------------------------------------------------------------
  ; Util functions
  ;-----------------------------------------------------------------------------
  (defun is-token-enabled:bool (token-id:string)
    (with-default-read tokens token-id {'enabled:false} {'enabled:=enabled}
      enabled))

  (defun is-sale-enabled:bool ()
    (with-default-read sales (pact-id) {'enabled:false} {'enabled:=enabled}
      enabled))

  ;-----------------------------------------------------------------------------
  ; Policy hooks
  ;-----------------------------------------------------------------------------
  ; Just after royalty
  (defun rank:integer ()
    (+ RANK-ROYALTY 1))

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
    (require-capability (POLICY-ENFORCE-OFFER token (pact-id) policy-extra-donation))
      (bind (read-sale-msg token) {'currency:=currency}
        (if (and (is-token-enabled (at 'id token))
                 (= (to-string currency) "coin"))
            (insert sales (pact-id) {'enabled:true})
            "")
        false)
  )

  (defun enforce-sale-withdraw:bool (token:object{token-info})
    true)

  (defun enforce-sale-buy:bool (token:object{token-info} buyer:string)
    true)

  (defun enforce-sale-settle:bool (token:object{token-info})
    (require-capability (POLICY-ENFORCE-SETTLE token (pact-id) policy-extra-donation))
    (if (and (is-sale-enabled)
             (<= SALE-MINIMUM (coin.get-balance (escrow))))
        (let ((_ 0))
          (install-capability (coin.TRANSFER (escrow) DONATION-ACCOUNT DONATION-AMOUNT))
          (coin.transfer (escrow) DONATION-ACCOUNT DONATION-AMOUNT)
          true)
        false)
  )

    (defun enable (token-id:string)
      (enforce-guard (get-guard-by-id token-id))
      (write tokens token-id {'enabled:true}))

    (defun disable (token-id:string)
      (enforce-guard (get-guard-by-id token-id))
      (write tokens token-id {'enabled:false}))

)
