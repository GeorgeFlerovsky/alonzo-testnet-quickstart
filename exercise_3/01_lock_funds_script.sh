#!/bin/bash
base_dir=$(dirname $0)

source $base_dir/common.sh

# ======================================================================
# Lock funds into script
# ===================================
lock_funds() {
  if [ -z $amount_to_send ]; then
    echo "Error: How much do you want to send?"
    exit 1
  fi

  echo Amount to Send: $amount_to_send

  if [ $utxos_with_my_datum_len -ne 0 ]; then
    echo "Utxos detected with this datum. It's better to either redeem them first, or choose another datum."
    exit 1
  fi

  if (( "$amount_to_send" < "$scaled_redemption_cost" )); then
    echo "Error: Amount to send ($amount_to_send) is insufficient to cover redemption cost ($scaled_redemption_cost)"
    exit 1
  fi

  # ===================================
  # Fee
  fee=$locking_fee
  echo Fee: $fee

  required_inflow=$(($fee + $amount_to_send + $scaled_redemption_cost))
  echo Required Inflow: $required_inflow

  # ===================================
  # Wallet utxo selection
  main_wallet_utxos_sufficient=$(cardano-wallet balance main | \
    jq -r --argjson payment "$required_inflow" \
    'to_entries | map(select(.value.value.lovelace >= $payment))')
  main_wallet_utxos_sufficient_len=$(echo $main_wallet_utxos_sufficient | jq 'length')
  echo Main Wallet: $(cardano-wallet main)
  echo Main Wallet Sufficient Utxos: $main_wallet_utxos_sufficient_len
  echo $main_wallet_utxos_sufficient

  # ===================================
  # Lovelace inflow and outflow
  inflow=$(echo $main_wallet_utxos_sufficient | jq -r '.[0].value.value.lovelace')
  echo Input Balance: $inflow

  amount_change=$(($inflow - $fee - $amount_to_send))
  echo Amount Change: $amount_change

  if (( "$amount_change" < "0" )); then
    echo "Error: Input Balance ($inflow) is insufficient to pay Amount to Send ($amount_to_send)"
    exit 1
  fi

  # ===================================
  # Inputs and outputs
  tx_in=$(echo $main_wallet_utxos_sufficient | jq -r '.[0].key')
  echo Tx In: $tx_in

  tx_in_signing_key=$(cardano-wallet signing-key main)
  echo Tx In Signing Key: $tx_in_signing_key

  tx_out_change="$(cardano-wallet main)+$amount_change"
  echo Tx Out Change: $tx_out_change

  tx_out_payment="$script_address+$amount_to_send"
  echo Tx Out Payment: $tx_out_payment

  # ===================================
  # Construct transaction
  setup_tx_file

  cardano-cli transaction build-raw --alonzo-era \
    --out-file $tx_file.unsigned \
    --fee $fee \
    --protocol-params-file $params_file \
    --tx-in $tx_in \
    --tx-out $tx_out_change \
    --tx-out $tx_out_payment \
    --tx-out-datum-hash $datum_hash

  if [ -f $tx_file.unsigned ]; then
    cardano-cli transaction sign --testnet-magic 5 \
      --out-file $tx_file.signed \
      --tx-body-file $tx_file.unsigned \
      --signing-key-file $tx_in_signing_key
  fi
}

# ======================================================================
# Main program
# ===================================
main() {
  case $operation in
    lock)
      common && lock_funds && submit
      ;;
    clean-tx-log)
      clean_tx_log
      ;;
    *)
      echo "Programming error: command $operation is not implemented."
      exit 201
      ;;
  esac

}

# ======================================================================
# Parse command-line arguments
# ===================================
OPTIONS=h
LONGOPTS=help

handle_args() {
  # Handle option args
  while true; do
      case "$1" in
          -h|--help)
              show_help
              exit 0
              ;;
          --)
              shift
              break
              ;;
          *)
              echo "Unknown options provided: $@"
              exit 51
              ;;
      esac
  done

  if [[ "$#" -eq 0 ]]; then
    show_help
    exit 0
  fi

  operation="$1"
  shift

  # Handle positional args
  case "$operation" in
    fund-collateral)
      amount_to_send="$1"
      shift
      ;;
    lock)
      amount_to_send="$1"
      shift
      ;;
    redeem)
      ;;
    clean-tx-log)
      ;;
    *)
      echo "Unknown operation: $@"
      exit 52
      ;;
  esac

  if [[ "$#" > 0 ]]; then
    echo "Unknown arguments provided for operation '$operation': '$@'"
    exit 53
  fi
}

show_help() {
  # Help message
  echo "$(basename "$0") - example script that implements Exercise 3"
  echo "for the Alonzo Testnet. Exercise 3 locks and then redeems"
  echo "some funds into/from a script that always succeeds."
  echo ""
  echo "Usage: $(basename "$0") [OPTIONS] OPERATION WALLET_ID"
  echo ""
  echo "Available options:"
  echo "  -h, --help                     display this help message"
  echo ""
  echo "Operations:"
  echo "  fund-collateral AMOUNT         send AMOUNT to collateral wallet"
  echo "  lock AMOUNT                    lock AMOUNT of funds into the script"
  echo "  redeem                         redeem funds from the script"
  echo "  clean-tx-log                   remove previous unsubmitted transactions"
}

# ======================================================================
# Let's go!
# ===================================

# Test whether getopt works
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  echoerr "'getopt --test' failed"
  exit 101
fi

# Parse command-line arguments, canonicalizing in-place
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  echoerr "Failed to parse arguments"
  exit 102
fi

# Handle arguments
eval handle_args "$PARSED"

# Perform the main program
main

