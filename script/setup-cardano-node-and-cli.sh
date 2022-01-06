#!/bin/bash

# # Setup IOHK binary cache
# if [ ! -f /etc/nix/nix.conf ]; then
#   if [! -d /etc/nix ]; then
#     sudo mkdir -p /etc/nix
#   fi
#   cat <<EOF | sudo tee /etc/nix/nix.conf
#   substituters = https://cache.nixos.org https://hydra.iohk.io https://iohk.cachix.org
#   trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ= iohk.cachix.org-1:DpRUyj7h7V830dp/i6Nti+NEO2/nhblbov/8MW7Rqoo=
#   EOF
# fi

cd $NODE_HOME

if [ ! -d .cardano-node ]; then
  git clone https://github.com/input-output-hk/cardano-node .cardano-node
  cd .cardano-node
else
  cd .cardano-node
  git switch -
  git pull
fi

git checkout tags/1.29.0

nix-build -A scripts.${NODE_VERSION_TAG}.node -o ../bin/cardano-node-${NODE_VERSION_TAG}
nix-build -A cardano-cli -o ../bin/cardano-cli

cd ..
