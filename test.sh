#!/bin/bash -x
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

. build/buildconf.sh

tempdir="$(mktemp -d)"
trap "rm -rf '${tempdir}'" EXIT
export PATH="${tempdir}:${PATH}"

function download-kubectl {
  local version="$1"
  local sha1="$2"
  local path="${tempdir}/kubectl-${version}"
  wget -O "${path}" "https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl"
  echo "${sha1} ${path}" | sha1sum -c
  chmod +x "${path}"
}

function select-kubectl {
  local version="$1"
  ln -fs "${tempdir}/kubectl-${version}" "${tempdir}/kubectl"
}

download-kubectl v1.4.9 5726e8f17d56a5efeb2a644d8e7e2fdd8da8b8fd
download-kubectl v1.5.3 295ced9fdbd4e1efd27d44f6322b4ef19ae10a12
download-kubectl v1.6.0-beta.2 ab400e5e2d6f0977f22e60a8e09cda924b348572

export DIND_IMAGE=mirantis/kubeadm-dind-cluster:local

function test-cluster {
  ./build/build-local.sh
  bash -x ./dind-cluster.sh clean
  time bash -x ./dind-cluster.sh up
  kubectl get pods -n kube-system | grep kube-dns
  time bash -x ./dind-cluster.sh up
  kubectl get pods -n kube-system | grep kube-dns
  bash -x ./dind-cluster.sh down
  bash -x ./dind-cluster.sh clean
}

(
  export KUBEADM_URL="${KUBEADM_URL_1_5_3}"
  export KUBEADM_SHA1="${KUBEADM_SHA1_1_5_3}"
  export HYPERKUBE_URL="${HYPERKUBE_URL_1_4_9}"
  export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_4_9}"
  select-kubectl v1.4.9
  test-cluster
)

(
  export KUBEADM_URL="${KUBEADM_URL_1_5_3}"
  export KUBEADM_SHA1="${KUBEADM_SHA1_1_5_3}"
  export HYPERKUBE_URL="${HYPERKUBE_URL_1_5_3}"
  export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_5_3}"
  select-kubectl v1.5.3
  test-cluster
)

# 1.6 fails on Travis (kube-proxy fails to restart after snapshotting)
if [[ ! ${TRAVIS:-} ]]; then
  (
    export KUBEADM_URL="${KUBEADM_URL_1_6_0_BETA_2}"
    export KUBEADM_SHA1="${KUBEADM_SHA1_1_6_0_BETA_2}"
    export HYPERKUBE_URL="${HYPERKUBE_URL_1_6_0_BETA_2}"
    export HYPERKUBE_SHA1="${HYPERKUBE_SHA1_1_6_0_BETA_2}"
    select-kubectl v1.6.0-beta.2
    test-cluster
  )
fi

echo "*** OK ***"
