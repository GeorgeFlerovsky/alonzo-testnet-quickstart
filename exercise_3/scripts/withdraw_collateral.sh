#!/bin/bash

# ======================================================================
# Withdraw funds from collateral wallet
# Note: receiver pays fee (i.e. deducted from funds deposited into main wallet)
# ===================================
withdraw_collateral() {
  if [ -z $amount_to_withdraw ]; then
    echo "Error: How much do you want to withdraw from the collateral wallet?"
    exit 1
  fi

  echo Amount to withdraw: $amount_to_withdraw

  # ===================================
  # Fee
  fee=$((200*1000))
  echo Fee: $fee

  required_inflow=$amount_to_withdraw
  echo Required Inflow: $required_inflow

  net_amount_to_withdraw=$(($amount_to_withdraw - $fee))
  echo "Net Amount to Withdraw (deducting fee): $net_amount_to_withdraw"

  # ===================================
  # Wallet utxo selection
  collateral_utxo_sufficient=$(cardano-wallet utxos collateral \
    | jq --argjson payment "$required_inflow" 'to_entries | map(select(.value.value.lovelace >= $payment))' \
    | jq 'min_by(.value.value.lovelace)')
  echo Collateral Wallet: $(cardano-wallet collateral)
  echo Collateral Wallet Sufficient Utxo:
  echo $collateral_utxo_sufficient

  if [ "$collateral_utxo_sufficient" == 'null' ]; then
    echo "Amount to withdraw ($amount_to_withdraw) cannot be fulfilled by any individual utxo in collateral wallet"
    exit 1
  fi

  # ===================================
  # Lovelace inflow and outflow
  inflow=$(echo $collateral_utxo_sufficient | jq -r '.value.value.lovelace')
  echo Input Balance: $inflow

  amount_change=$(($inflow - $amount_to_withdraw))
  echo Amount Change: $amount_change

  # ===================================
  # Inputs and outputs
  tx_in=$(echo $collateral_utxo_sufficient | jq -r '.key')
  echo Tx In: $tx_in

  tx_in_signing_key=$(cardano-wallet signing-key collateral)
  echo Tx In Signing Key: $tx_in_signing_key

  tx_out_change="$(cardano-wallet collateral)+$amount_change"
  echo Tx Out Change: $tx_out_change

  tx_out_payment="$(cardano-wallet main)+$net_amount_to_withdraw"
  echo Tx Out Payment: $tx_out_payment

  # ===================================
  # Construct transaction
  setup_tx_file
  echo Tx File: $tx_file

  get_tx_expiry_slot $((5 * 60))
  echo Tx Expiry Slot: $tx_expiry_slot

  cardano-cli query protocol-parameters --testnet-magic ${TESTNET_MAGIC} --out-file $tx_file.params

  cardano-cli transaction build-raw --mary-era \
    --out-file $tx_file.unsigned \
    --invalid-hereafter $tx_expiry_slot \
    --fee $fee \
    --tx-in $tx_in \
    --tx-out $tx_out_change \
    --tx-out $tx_out_payment

  if [ -f $tx_file.unsigned ]; then
    cardano-cli transaction sign --testnet-magic ${TESTNET_MAGIC} \
      --out-file $tx_file.signed \
      --tx-body-file $tx_file.unsigned \
      --signing-key-file $tx_in_signing_key
  fi
}
