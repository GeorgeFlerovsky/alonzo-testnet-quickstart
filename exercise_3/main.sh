#!/bin/bash

# ======================================================================
# Main program
# ===================================
main() {
  cd $(dirname $0)

  source "./scripts/utils.sh"
  source "./scripts/prepare_for_plutus_script.sh"
  source "./scripts/fund_collateral.sh"
  source "./scripts/withdraw_collateral.sh"
  source "./scripts/lock_funds.sh"
  source "./scripts/redeem_funds.sh"

  case $operation in
    fund-collateral)
      prepare_for_plutus_script \
        && fund_collateral \
        && submit
      ;;
    withdraw-collateral)
      withdraw_collateral \
        && submit
      ;;
    lock-funds)
      prepare_for_plutus_script \
        && lock_funds \
        && submit
      ;;
    redeem-funds)
      prepare_for_plutus_script \
        && redeem_funds \
        && submit
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
# Parse and handle command-line arguments
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
    withdraw-collateral)
      amount_to_withdraw="$1"
      shift
      ;;
    lock-funds)
      amount_to_send="$1"
      shift
      ;;
    redeem-funds)
      ;;
    clean-tx-log)
      ;;
    *)
      echo "Unknown operation: $operation"
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
  echo "  lock-funds AMOUNT              lock AMOUNT of funds into the script"
  echo "  redeem-funds                   redeem funds from the script"
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

