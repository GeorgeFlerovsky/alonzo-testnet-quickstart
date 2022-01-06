#!/bin/bash

# ======================================================================
# Transaction expiry slot
# ===================================
get_tx_expiry_slot() {
  if [ "$#" -eq 0 ]; then
    echo "Missing argument for get_tx_expiry_slot/1: how much should the transaction"
    echo "expiry slot be offset from the slot when it is submitted?"
    exit 1
  fi

  current_slot=$(cardano-cli query tip --testnet-magic ${TESTNET_MAGIC} | jq '.slot')

  tx_expiry_slot=$(($current_slot + $1))
}

# ======================================================================
# Log generated and submitted transactions
# ===================================
clean_tx_log() {
  cd "./tx"
  transactions=$(ls \
    | jq -R \
    | jq --slurp 'map(capture("(?<name>.+)\\.(?<ext>\\w+)$")) | group_by(.name)' \
    | jq 'map(select(map(.ext) | contains(["submitted"]) | not))' \
    | jq 'flatten | map("\(.name).\(.ext)") | join (" ")' \
    | jq -r)
  if [ ! -z "$transactions" ]; then
    rm --verbose $transactions
  fi
}

setup_tx_file() {
  [ -d "./tx/" ] || mkdir "./tx/"

  tx_name="transaction_$(date +'%Y-%m-%d_%T')_$operation"

  tx_file="./tx/$tx_name"
}

# ======================================================================
# Submit transaction
# ===================================
submit() {
  if [ -f $tx_file.signed ]; then
    read -p "Are you sure you want to submit this transaction (y/n)? " -n 1 -r approve_submit
    echo ""
    if [[ $approve_submit =~ ^[Yy]$ ]]; then
      touch $tx_file.submitted
      cardano-cli transaction submit --testnet-magic ${TESTNET_MAGIC} --tx-file $tx_file.signed
    fi
  fi
}

