#!/bin/bash

# ======================================================================
# Lock funds into script
# ===================================
lock_funds() {
  if [ -z $amount_to_send ]; then
    echo "Error: How much do you want to send?"
    exit 1
  fi

  echo Amount to Send: $amount_to_send

  if (( "$amount_to_send" < "$scaled_redemption_cost" )); then
    echo "Error: Amount to send ($amount_to_send) is insufficient to cover redemption cost ($scaled_redemption_cost)"
    exit 1
  fi

  # ===================================
  # Script utxo selection
  script_utxo_with_my_datum=$(cardano-wallet utxos-script $script_file \
    | jq --arg utxo $datum_hash 'to_entries | map(select(.value.data == $utxo))' \
    | jq 'max_by(.value.value.lovelace)')
  echo Script Utxo with My Datum:
  echo $script_utxo_with_my_datum

  if [ "$script_utxo_with_my_datum" != 'null' ]; then
    echo "Utxos detected with this datum. It's better to either redeem them first, or choose another datum."
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
  main_wallet_utxo_sufficient=$(cardano-wallet utxos main \
    | jq --argjson payment "$required_inflow" 'to_entries | map(select(.value.value.lovelace >= $payment))' \
    | jq 'min_by(.value.value.lovelace)')
  echo Main Wallet: $(cardano-wallet main)
  echo Main Wallet Sufficient Utxo:
  echo $main_wallet_utxo_sufficient

  # ===================================
  # Lovelace inflow and outflow
  inflow=$(echo $main_wallet_utxo_sufficient | jq -r '.value.value.lovelace')
  echo Input Balance: $inflow

  amount_change=$(($inflow - $fee - $amount_to_send))
  echo Amount Change: $amount_change

  if (( "$amount_change" < "0" )); then
    echo "Error: Input Balance ($inflow) is insufficient to pay Amount to Send ($amount_to_send)"
    exit 1
  fi

  # ===================================
  # Inputs and outputs
  tx_in=$(echo $main_wallet_utxo_sufficient | jq -r '.key')
  echo "Tx In (Main): $tx_in"

  tx_in_signing_key=$(cardano-wallet signing-key main)
  echo "Tx In (Main) Signing Key: $tx_in_signing_key"

  tx_out_change="$(cardano-wallet main)+$amount_change"
  echo "Tx Out (Main) Change: $tx_out_change"

  tx_out_payment="$script_address+$amount_to_send"
  echo "Tx Out (Script) Payment: $tx_out_payment"

  # ===================================
  # Construct transaction
  setup_tx_file
  echo Tx File: $tx_file

  get_tx_expiry_slot $((5 * 60))
  echo Tx Expiry Slot: $tx_expiry_slot

  cp $datum_file $tx_file.datum

  cardano-cli query protocol-parameters --testnet-magic ${TESTNET_MAGIC} --out-file $tx_file.params

  cardano-cli transaction build-raw --alonzo-era \
    --out-file $tx_file.unsigned \
    --invalid-hereafter $tx_expiry_slot \
    --fee $fee \
    --protocol-params-file $tx_file.params \
    --tx-in $tx_in \
    --tx-out $tx_out_change \
    --tx-out $tx_out_payment \
    --tx-out-datum-hash $datum_hash

  if [ -f $tx_file.unsigned ]; then
    cardano-cli transaction sign --testnet-magic ${TESTNET_MAGIC} \
      --out-file $tx_file.signed \
      --tx-body-file $tx_file.unsigned \
      --signing-key-file $tx_in_signing_key
  fi
}

