set -euo pipefail

# Usage:
#   ./generate-ecr-pull-secret.sh <aws_account_id> [region] [secret_name] [namespace]
#
# Example:
#   ./generate-ecr-pull-secret.sh 123456789012 eu-central-1 ecr-pull-secret default > ecr-pull-secret.yaml
#   kubectl apply -f ecr-pull-secret.yaml

ACCOUNT_ID="${1:-}"
REGION="${2:-eu-central-1}"
SECRET_NAME="${3:-ecr-pull-secret}"
NAMESPACE="${4:-default}"

if [[ -z "${ACCOUNT_ID}" ]]; then
  echo "Usage: $0 <aws_account_id> [region] [secret_name] [namespace]" >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI not found" >&2
  exit 1
fi

REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
PASSWORD="$(aws ecr get-login-password --region "${REGION}")"

if [[ -z "${PASSWORD}" ]]; then
  echo "Error: failed to get ECR login password" >&2
  exit 1
fi

b64() {
  if base64 --help 2>/dev/null | grep -q -- '-w'; then
    base64 -w 0
  else
    base64 | tr -d '\n'
  fi
}

AUTH="$(printf 'AWS:%s' "${PASSWORD}" | b64)"
DOCKER_CONFIG_JSON="$(cat <<EOF
{"auths":{"${REGISTRY}":{"username":"AWS","password":"${PASSWORD}","auth":"${AUTH}"}}}
EOF
)"

DOCKER_CONFIG_JSON_B64="$(printf '%s' "${DOCKER_CONFIG_JSON}" | b64)"

cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${DOCKER_CONFIG_JSON_B64}
EOF
