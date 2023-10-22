# Marmalade Extra Policies Examples

Quick and dirty Testnet's examples for Extra policies.

Low quality and possibly unsafe code. For example purpose (at least now). Currently, they are not intended to go to Mainnet.

*``policy-extra-currency-whitelist``: Whitelist some currencies authorized for a token sale.

*``policy-extra-donation``: Donate 0.1 KDA on each sale for solidarity.

*``policy-extra-multi-sellers``: Divide the sell price between a list of sellers

*``policy-extra-lottery``: Create a lottery to win the NFT. Each potential buyer bids a certain amount. The winner of the NFT is randomly drawn.

Of course, since  extra policy, a token issuer has the possibility to disable them by either:
* Not including the standard ``policy-extra-policies`` at all.
* Blacklisting


## policy-extra-currency-whitelist

Useful only when the token has no royalty policies enabled (royalty policies already have the feature)

The policy must be enabled by the token creator using:

```pact
 (defun update-allowed-currencies:string (token-id:string currencies:[module{fungible-v2}]))
 ```

And can be disabled with:

```pact
(defun allow-all-currencies:string (token-id:string)
 ```

## policy-extra-donation

Donate 0.1 KDA for each sale. This donation is automatically made in addition to the Marketplace fees, and royalties.

The feature is not enabled by default. It should be enabled using:

```pact
 (defun enable (token-id:string)
```

And disabled with:

```pact
 (defun disable (token-id:string)
```

## policy-extra-multi-sellers

Allows to divide the sale price between different seller accounts. This policy is sale mechanism agnostic. It will work for all sales mechanisms (fixed price, auctions, lottery, ...)

The policy must be allowed during the sale offer by adding the field ``multi_seller`` in data.

Example: *The sale amount in KDA will be divided (2.0 for each) by alice, carol and dave*

```json
{ "marmalade_fixed_quote": {"recipient":"alice", "price":6.0 },
  "marmalade_sale": {"sale_type":"fixed", "currency":coin },
  "marmalade_multi_sellers": {"accounts":["carol", "dave"]}
 }
```

## policy-extra-lottery

**IMPORTANT NOTE**: This policy is fundamentally unsafe. Without a trusted Oracle, on-chain generated random numbers can be attacked. Let's assume that this is only a Proof of Concept.

Allow to sale of  NFTs using a lottery. Instead of fixing a price for the NFT, the seller chooses a ticket price.

Each buyer interested for obtaining the NFT buys a ticket. After the timeout has elapsed, one of the tickets buyer is randomly chosen to receive the NFT.


The policy must be triggered during the sale offer with the sale_type: `lottery`:

```json
{"marmalade_sale": {"sale_type":"lottery", "currency":coin },
                    "marmalade_lottery": {"recipient":"alice", "ticket_price":1.0 }
         })
```

A buyer can buy a ticket using:

```pact
(defun buy-ticket:string (sale-id:string buyer:string)
```

After the timeout has elapsed, someone must call to select a random winner:

```pact
(defun draw:string (sale-id:string)
```


Before claiming the funds, the winning account can be determined using:

```pact
(defun get-lottery:object{token-lottery-sch} (sale-id:string)
```
