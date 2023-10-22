(module policy-extra-lottery GOVERNANCE
  (implements marmalade-ng.token-policy-ng-v1)
  (use marmalade-ng.token-policy-ng-v1 [token-info])
  (use marmalade-ng.ledger [NO-TIMEOUT escrow escrow-guard])
  (use marmalade-ng.policy-extra-policies)
  (use marmalade-ng.util-policies)
  (use free.util-lists)
  (use free.util-math)
  (use free.util-time)
  (use free.util-random)


  ;-----------------------------------------------------------------------------
  ; Governance
  ;-----------------------------------------------------------------------------
  (defconst ADMIN-KEYSET:string (read-string "extra_examples_keyset"))
  (defcap GOVERNANCE ()
   (enforce-keyset ADMIN-KEYSET))

   ;-----------------------------------------------------------------------------
   ; Capabilities and events
   ;-----------------------------------------------------------------------------
   (defcap LOTTERY-OFFER (sale-id:string token-id:string ticket-price:decimal)
     @doc "Event sent when lottery started"
     @event
     true)

  (defcap TICKET-BOUGHT (sale-id:string token-id:string buyer:string)
     @doc "Event sent when a ticket is bought"
     @event
     true)

  (defcap DRAWN (sale-id:string token-id:string rnd-number:integer winner:string)
    @doc "Event sent when a ticket is bought"
    @event
    true)


  (defcap TOKEN-BOUGHT (sale-id:string token-id:string)
    @doc "Event sent when the otken of a lottery is bought"
    @event
    true)

  (defcap LOTTERY-WITHDRAWN (sale-id:string token-id:string)
    @doc "Event sent when a lottery is withdrawn"
    @event
    true)


  ;-----------------------------------------------------------------------------
  ; Tables and schema
  ;-----------------------------------------------------------------------------

  (defschema token-lottery-sch
    sale-id:string
    token-id:string
    seller:string
    amount:decimal
    escrow-account:string
    currency:module{fungible-v2}
    ticket-price:decimal
    tickets-bought:[string]
    winner:string
    recipient:string
    timeout:time
    enabled:bool
  )

  (deftable sales:{token-lottery-sch})

  ;-----------------------------------------------------------------------------
  ; Input data
  ;-----------------------------------------------------------------------------
  (defschema lottery-msg-sch
    ticket_price:decimal
    recipient:string
  )


  (defun read-lottery-msg-sch:object{lottery-msg-sch} (token:object{token-info})
    (enforce-get-msg-data "lottery" token ))

  ;-----------------------------------------------------------------------------
  ; Util functions
  ;-----------------------------------------------------------------------------
  (defun is-sale-registered:bool ()
    (with-default-read sales (pact-id) {'sale-id:""} {'sale-id:=sale-id}
      (!= "" sale-id))
  )

  (defun enforce-before-timeout:bool (sale-id:string)
    (with-read sales sale-id {'timeout:=timeout}
      (enforce (is-future timeout) "Must happen before timeout"))
  )

  (defun enforce-after-timeout:bool (sale-id:string)
    (with-read sales sale-id {'timeout:=timeout}
      (enforce (is-past timeout) "Must happen after timeout"))
  )

  (defun enforce-pact-after-timeout:bool ()
    (enforce-after-timeout (pact-id))
  )

  ;-----------------------------------------------------------------------------
  ; Policy hooks
  ;-----------------------------------------------------------------------------
  (defun rank:integer ()
    RANK-SALE)

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
    (require-capability (POLICY-ENFORCE-OFFER token (pact-id) policy-extra-lottery))
    (bind (read-sale-msg token) {'sale_type:=sale-type,
                                 'currency:=currency:module{fungible-v2}}
      (if (= sale-type "lottery")
        (bind (read-lottery-msg-sch token) {'ticket_price:=ticket-price, 'recipient:=recipient}
          (check-price currency ticket-price)

          (enforce (!= NO-TIMEOUT timeout) "No timeout not supported for auction sale")

          ; Check that the recipient account already exists in the currency
          (check-fungible-account currency recipient)

          (bind token {'id:=token-id}
            ; Insert the quote into the DB
            (insert sales (pact-id) {'sale-id: (pact-id),
                                      'token-id: token-id,
                                      'seller: seller,
                                      'amount:amount,
                                      'escrow-account: (escrow),
                                      'currency: currency,
                                      'ticket-price: ticket-price,
                                      'tickets-bought:[],
                                      'winner:"",
                                      'recipient: recipient,
                                      'timeout: timeout,
                                      'enabled: true})
            (currency::create-account (escrow) (escrow-guard))
            ; Emit event always returns true
            (emit-event (LOTTERY-OFFER (pact-id) token-id ticket-price))))
        false))
  )

  (defun --enforce-sale-withdraw:bool (token:object{token-info})
    (require-capability (POLICY-ENFORCE-WITHDRAW token (pact-id) policy-extra-lottery))
    (enforce-pact-after-timeout)
    (with-read sales (pact-id) {'tickets-bought:=tickets}
      (enforce (is-empty tickets) "Tickets sold"))
    (update sales (pact-id) {'enabled: false})
    true
  )

  (defun enforce-sale-withdraw:bool (token:object{token-info})
    (if (is-sale-registered)
        (--enforce-sale-withdraw token)
        false)
  )

  (defun --enforce-sale-buy:bool (token:object{token-info} buyer:string)
    (require-capability (POLICY-ENFORCE-BUY token (pact-id) policy-extra-lottery))
    (enforce-pact-after-timeout)
    (with-read sales (pact-id) {'tickets-bought:=tickets,
                                'winner:=winner}
      (enforce (is-not-empty tickets) "No tickets sold")
      (enforce (!= "" winner) "Lottery hasn't been drawn")
      (enforce (= buyer winner) "Bad buyer")
      true)
  )

  (defun enforce-sale-buy:bool (token:object{token-info} buyer:string)
    (if (is-sale-registered)
        (--enforce-sale-buy token buyer)
        false)
  )

  (defun --enforce-sale-settle:bool (token:object{token-info})
    (require-capability (POLICY-ENFORCE-SETTLE token (pact-id) policy-extra-lottery))
    (with-read sales (pact-id) {'currency:=currency:module{fungible-v2},
                                'recipient:=recipient}
      (let* ((escrow (escrow))
             (escrow-total-bal (currency::get-balance escrow)))
        (install-capability (currency::TRANSFER escrow recipient escrow-total-bal))
        (currency::transfer escrow recipient escrow-total-bal)))
    ; Disable the sale
    (update sales (pact-id) {'enabled: false})
    true
  )

  (defun enforce-sale-settle:bool (token:object{token-info})
    (if (is-sale-registered)
        (--enforce-sale-settle token)
        false)
  )

  (defun buy-ticket:string (sale-id:string buyer:string)
    (enforce-before-timeout sale-id)
    (with-read sales sale-id {'ticket-price:=ticket-price,
                              'token-id:=token-id,
                              'escrow-account:=escrow,
                              'tickets-bought:=tickets,
                              'currency:=currency:module{fungible-v2}}
      (check-fungible-account currency buyer)
      (enforce (> 100 (length tickets)) "Tickets limit reached")
      (currency::transfer buyer escrow ticket-price)

      (update sales sale-id {'tickets-bought:(append-last tickets buyer)})
      (emit-event (TICKET-BOUGHT sale-id token-id buyer))
      (format "Ticket bought for {}" [token-id]))
  )

  (defun draw:string (sale-id:string)
    ;;; WARNING UNSAFE FUNCTION SHOULD BE FED BY AN ORACLE
    (enforce-after-timeout sale-id)
    (with-read sales sale-id {'token-id:=token-id,
                              'tickets-bought:=tickets,
                              'winner:=current-winner}
      (enforce (= "" current-winner) "Lottery already drawn")
      (let* ((rnd-number (if (is-singleton tickets) 0 (random-int-range 0 (-- (length tickets)))))
             (winner (at rnd-number tickets)))
        (update sales sale-id {'winner: winner })
        (emit-event (DRAWN sale-id token-id rnd-number winner))
        (format "Winner is {}" [winner])))
  )

  ;-----------------------------------------------------------------------------
  ; View functions
  ;-----------------------------------------------------------------------------
  (defun get-lottery:object{token-lottery-sch} (sale-id:string)
    (read sales sale-id))
)
