#!/bin/bash

# ======================================================================
# Prepare variables for a transaction involving a plutus script
# ===================================
prepare_for_plutus_script() {
  # ===================================
  # Script and datum
  script_file="./plutus/helloworld-parametric.plutus"
  script_budget_file="$script_file.budget.json"
  if [ ! -f "$script_file" ] || [ ! -f "$script_budget_file" ]; then
    echo "Script files do not exist!"
    exit 1
  fi

  script_address=$(cardano-wallet address-script $script_file)
  echo Script File: $script_file
  echo Script Address: $script_address

  datum_file="./datum.txt"
  if [ ! -f "$datum_file" ]; then
    echo "Datum file ($datum_file) does not exist."
    echo "Please create one with the following command and put it in the exercise_3 folder:"
    echo "  echo \"\\\"\$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)\\\"\" > datum.txt"
    exit 1
  fi

  datum=$(cat datum.txt)
  echo Datum: $datum
  datum_hash=$(cardano-cli transaction hash-script-data --script-data-value "$datum")
  echo Datum Hash: $datum_hash

  # ===================================
  # Locking cost
  locking_fee=$((250*1000))
  echo Locking fee: $locking_fee

  # ===================================
  # Redemption cost
  fixed_cost=$((1000*1000))
  echo Fixed cost: $fixed_cost

  min_execution_units=$(cat $script_budget_file | jq)

  min_execution_cost=$(jq -n -r \
    --argjson fixed_cost $fixed_cost \
    --argjson prices "$(cardano-cli query protocol-parameters --testnet-magic ${TESTNET_MAGIC} | jq '.executionUnitPrices')" \
    --argjson budget "$min_execution_units" \
    '{"Steps": (($prices.priceSteps.numerator / $prices.priceSteps.denominator) * $budget.Steps), "Memory": (($prices.priceMemory.numerator / $prices.priceMemory.denominator) * $budget.Memory)} | add')

  min_redemption_cost=$(($min_execution_cost + $fixed_cost))
  echo Minimum Cost to Redeem: $min_redemption_cost

  scalar_factor=30
  scaled_execution_units=$(echo $min_execution_units | jq --argjson factor $scalar_factor 'map_values(. * $factor)')
  scaled_execution_cost=$(($min_redemption_cost * $scalar_factor))
  scaled_redemption_cost=$(($scaled_execution_cost + $fixed_cost))
  echo "Scalar factor: $scalar_factor"
  echo "Scaled-up Execution Units to Redeem (just in case): $scaled_execution_units"
  echo "Scaled-up Cost to Redeem (just in case): $scaled_redemption_cost"

  execution_units="($(echo $scaled_execution_units | jq -r 'join (", ")'))"
  echo Execution Units: $execution_units

  # ===================================
  # Required collateral
  collateral_percentage=$(cardano-cli query protocol-parameters --testnet-magic ${TESTNET_MAGIC} | jq -r '.collateralPercentage')
  collateral_value_required=$(($scaled_redemption_cost * $collateral_percentage / 100))
  echo Collateral Percentage Required: $collateral_percentage%
  echo Collateral Value Required: $collateral_value_required
}

