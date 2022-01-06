# Alonzo testnet quickstart
This repository is intended to help people get started quickly with the Alonzo Purple testnet. In particular, it contains some fairly robust and convenient scripts that implement some of the testnet exercises.

## Prerequisites
This project has been developed/tested on a Linux system, and it requires the following utilities:
- [direnv](https://direnv.net/)
- [nix](https://nixos.org/guides/install-nix.html)
- [jq](https://stedolan.github.io/jq/)

## Setup

Clone this repository and enter the resulting directory.

Take a look at the `.envrc` file to see what environment variables and path it sets up. Enable direnv:
```
[user@machine alonzo-testnet]$ direnv allow
```

Ensure that you have the IOG binary caches for nix setup:
```
[user@machine alonzo-testnet]$ cat /etc/nix/nix.conf
substituters        = https://hydra.iohk.io https://iohk.cachix.org https://cache.nixos.org/
trusted-public-keys = hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

Install cardano-node and cardano-cli (using nix):
```
[user@machine alonzo-testnet]$ setup-cardano-node-and-cli.sh
```

## Run and monitor a passive cardano node
Start cardano node:
```
[user@machine alonzo-testnet]$ cd $NODE_HOME && cardano-node-${NODE_VERSION_TAG} &> node.log
```

Open another terminal tab to monitor the node. For example, if you have the [lnav](https://lnav.org/) utility installed:
```
[user@machine alonzo-testnet]$ lnav -t -c ':goto 100%' $NODE_HOME/node.log
```

## Cardano-wallet utility
The helper script `scripts/cardano-wallet` makes it easier to manage several "wallets" (a wallet includes an address, a payment skey/vkey pair, and a staking skey/vkey pair).

These credentials for each wallet are stored in respective subfolders under `./wallet`, which is ignored by git commits.

Usage:
```
[user@machine alonzo-testnet]$ cardano-wallet --help
cardano-wallet - Helper script to handle "wallets" in
the Alonzo Testnet. A "wallet" is a set of skeys/vkeys
for payment/staking, plus a public address.

Usage: cardano-wallet [OPTIONS] OPERATION (WALLET_ID | SCRIPT_FILE)

Available options:
  -h, --help                     display this help message
  -y, --yes                      do not ask for confirmation of destructive operations

Operations (default = address):
  address WALLET_ID              get the address for the wallet called WALLET_ID
  address-script SCRIPT_FILE     get the address for a script located at SCRIPT_FILE
  balance WALLET_ID              get the balance for the wallet called WALLET_ID
  balance-script SCRIPT_FILE     get the balance for a script located at SCRIPT_FILE
  utxos WALLET_ID                get the UTxOs for the wallet called WALLET_ID
  utxos-script SCRIPT_FILE       get the UTxOs for a script located at SCRIPT_FILE
  create WALLET_ID               create a wallet called WALLET_ID
  remove WALLET_ID               remove the wallet called WALLET_ID
  signing-key WALLET_ID          get the signing key for the wallet called WALLET_ID
  verification-key WALLET_ID     get the verification key for the wallet called WALLET_ID
```

## Wallet setup for exercises
The scripts for the exercises in this repository assume that you have two wallets:
- `main` holds most of your funds
- `collateral` holds the utxos that you will use as collateral when consuming script-guarded utxos

Create two wallets 'main' and 'collateral':
```
[user@machine alonzo-testnet]$ cardano-wallet create main
Creating wallet main at $NODE_HOME/wallet/main

[user@machine alonzo-testnet]$ cardano-wallet create collateral
Creating wallet main at $NODE_HOME/wallet/collateral
```

Beg friends/family for Alonzo testnet ADA, which should be sent to the 'main' address:
```
[user@machine alonzo-testnet]$ echo $(cardano-wallet main)
addr_test...
```

## Exercise 3
In this exercise, you are asked to interact with the most trivial on-chain validator, which succeeds regardless of the (datum, redeemer, transaction context) that it is provided with:
```haskell
validator :: Data -> Data -> Data -> ()
validator _ _ _ = ()
```

This validator has been compiled and serialized and saved at [./exercise_3/plutus/always-succeeds.plutus](./exercise_3/plutus/always-succeeds.plutus).

The trick with this exercise is making sure that the datum-hash you provide when locking funds under the validator matches the datum that you provide when redeeming funds from the validator.

More info: [./exercise_3/README.md](./exercise_3/README.md).

## Exercise 4: Helloworld parametric
In this exercise, you are asked to interact with a slightly more complicated on-chain validator, which succeeds if it is provided with a text datum `"Hello World!"`, ignoring the redeemer and transaction context. For various technical reasons, this validator had to be written in parametric form, where the keyword to which the datum is compared is passed in as an additional argument.
```haskell
hello :: P.ByteString
hello = "Hello World!"

{-# INLINABLE helloWorld #-}
helloWorld :: P.ByteString -> P.ByteString -> P.ByteString -> ScriptContext -> P.Bool
helloWorld keyword datum redeemer context = keyword P.== datum

data HelloWorld
instance Scripts.ValidatorTypes HelloWorld where
    type instance DatumType HelloWorld = P.ByteString
    type instance RedeemerType HelloWorld = P.ByteString

helloWorldInstance :: Scripts.TypedValidator HelloWorld
helloWorldInstance = Scripts.mkTypedValidator @HelloWorld
    ($$(PlutusTx.compile [|| helloWorld ||]) `PlutusTx.applyCode` PlutusTx.liftCode hello)
    $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = Scripts.wrapValidator @P.ByteString @P.ByteString
```

This validator has been compiled and serialized and saved at [./exercise_4_helloworld_parametric/plutus/helloworld-parametric.plutus](./exercise_4_helloworld_parametric/plutus/helloworld-parametric.plutus).

As with the previous exercise, the trick with this exercise is making sure that the datum-hash you provide when locking funds under the validator matches the datum that you provide when redeeming funds from the validator. Also, the datum needs to be `"Hello World!"`.

More info: [./exercise_4_helloworld_parametric/README.md](./exercise_4_helloworld_parametric/README.md).

