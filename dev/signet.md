# Testing signet

Documentation of testing options with the wider network since the dev setup makes is possible to start a signet instance.

## General notes about signet
### Advantages
- it is a network where intreaction is possible with other instances and projects
- funds are worthless just like on testnet
- the derivation paths are same as on testnet
- reliable blocktimes
- no block-storms
- small blockchain (IBD ~ 10 mins on a laptop)
- Faucets are available (see below)

### Disadvantages
- no lndmon support yet https://github.com/lightninglabs/lndmon/issues/80
- no Loop support yet https://github.com/lightninglabs/loop/issues/522
- fewer nodes on the network
- staging would need an accounting reset when converting (might be an advantage)
- no known 3rd party services / test shops available
- pending in:
  - https://github.com/alexbosworth/ln-sync/issues/5
  - https://github.com/bitcoinjs/bitcoinjs-lib/issues/1820

## Public Electrum servers
* signet-electrumx.wakiyamap.dev:50002:s
* electrum.emzy.de:53002:s
* node202.fra.mempool.space:60602:s

## Block explorer
* https://mempool.space/signet
* https://explorer.bc-2.jp/

## Faucets
- https://signet.bc-2.jp/
- https://signetfaucet.bublina.eu.org/
- https://faucet.sirion.io/ (LN only)

## LN explorers
- https://mempool.space/signet/lightning
- https://signet-lightning.wakiyamap.dev/

## Test payment destinations
* LN address on staging: `test@pay.staging.blink.sv`
* Staging cash resgister: https://pay.staging.blink.sv/test?amount=0&sats=0&unit=CENT&memo=&display=USD&currency=USD
* BTCPay PoS (LN - BOLT11) https://sigpay.sirion.io/apps/33Au5UDsPWnUL5GVT8q1Yjovw83K/crowdfund
* BTCPay PoS (onchain) https://signet.demo.btcpayserver.org/apps/2SCdQhwFm464BcHxXn44kRVg3iCr/pos

## Other wallets with signet support
### [OBW](https://github.com/nbd-wtf/obw/releases/)
* for Android only with LN support
* To use a hosted channel scan the QRcode with OBW-signet (should also provide some local balance ):

<a href="url"><img src="https://user-images.githubusercontent.com/43343391/206720745-838fb788-d09d-4af9-8400-32c2137dd30b.png" align="middle" height="200" width="200">
</a>

### [Sparrow Wallet](https://sparrowwallet.com/download/)
Supports onchain only, but works well with Taproot accounts. To use it with signet open:
 menu - Tools - Restart  in Testnet and set a Private Electrum server serving signet like: `node202.fra.mempool.space` port: `60602` with SSL.`

### [Electrum Wallet](https://electrum.org/#download)
* Support onchain (no Taproot yet) and LN, but couldn't send or receive lightning payments on signet with electrum yet.
* start with the signet flag eg:
    ```
    electrum-4.4.0-x86_64.AppImage --signet
    ```
* `menu` - `Wallet` - `Information` and restart to activate lightning

## Galoy staging node to open channels to
* [Galoy staging LND1](https://mempool.space/signet/lightning/node/024e679c1a77143029b806f396f935fa6cd0744970f412667adfc75edbbab54d7a)
* Scan the URI to open a channel:

<a href="url"><img src="https://user-images.githubusercontent.com/43343391/200599602-093133de-4d40-4ab3-9ed6-4f4af1d4527c.png" align="middle" height="200" width="200">
</a>

## Resources
* General documentation on signet: https://en.bitcoin.it/wiki/Signet
* Plebnet playground using a separate signet: https://www.plebnet.fun/
* Custom signet by Mutiny: https://blog.mutinywallet.com/mutinynet/?ref=nobsbitcoin.com

