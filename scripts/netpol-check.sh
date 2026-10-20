#!/usr/bin/bash

set -o errexit
set -o pipefail

KUBERNETES_DIR=$1

[[ -z "${KUBERNETES_DIR}" ]] && echo "Kubernetes location not specified" && exit 1

violations=$(
  find "${KUBERNETES_DIR}" -type f -name '*.yaml' ! -name '*.sops.yaml' -print0 |
    xargs -0 yq -N -o=tsv '
      select(tag == "!!map")
      | select(.kind == "CiliumNetworkPolicy" or .kind == "CiliumClusterwideNetworkPolicy")
      | select(.metadata.annotations["home-infra/broad-egress"] == null)
      | .metadata as $m
      | (.spec.egress // [])[] | (.toEntities // [])[]
      | select(. == "world" or . == "cluster" or . == "all")
      | [filename, $m.namespace // "cluster-wide", $m.name, .]' |
    sort -u
)

if [[ -n "${violations}" ]]; then
  echo "Egress to broad entities requires a home-infra/broad-egress annotation with a reason:"
  echo "${violations}"
  exit 1
fi

echo "No unannotated broad egress rules"
