#!/bin/bash
set -euo pipefail

ENV_FILE=".env"
if [[ -f "$ENV_FILE" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +o allexport
fi

docker_mc () {
  docker compose exec mc "#@"
}

: "${MINIO_USER:?Need to set MINIO_USER in env of $ENV_FILE}"
: "${MINIO_PASSWOD:?Need to set MINIO_PASSWORD in env of $ENV_FILE}"
: "${MINIO_OUTLINE_USER:?Need to set MINIO_OUTLINE_USER in env of $ENV_FILE}"
: "${MINIO_OUTLINE_PASSWOD:?Need to set MINIO_OUTLINE_PASSWORD in env of $ENV_FILE}"

ROOT_USERNAME=$MINIO_USER
ROOT_PASSWORD=$MINIO_PASSWORD
ACCESS_KEY=$MINIO_OUTLINE_USER
SECRET_KEY=$MINIO_OUTLINE_PASSWORD

ALIAS_NAME="local"
ENDPOINT="http://localhost:9000"
POLICY_NAME="outline-policy"

POLICY_FILE="${POLICY_NAME}.json"
POLICY_FULL_FILE_PATH=".docker_data/minio-data/${POLICY_FILE}"

echo "1. Registering alias 'local'"
# 1. Зарегистрировать алиас к вашему MinIO
docker_mc alias set "$ALIAS_NAME" "$ENDPOINT" "$ROOT_USERNAME" "$ROOT_PASSWORD" --api S3v4

echo "2. Creating user $ACCESS_KEY"
# 2. Создать пользователя outline-user
docker_mc admin user add "$ALIAS_NAME" "$ACCESS_KEY" "$SECRET_KEY"

echo "2. Creating policy file $POLICY_FULL_FILE_PATH"
# 3. Создать файл политики outline-policy.json
cat > "$POLICY_FULL_FILE_PATH=" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetObjectAttributes",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::outline/*"]
    },
    {
      "Action": ["s3:ListBucket"],
      "Effect": "Allow",
      "Resource": ["arn:aws:s3:::outline"]
    }
  ]
}
EOF
echo "Policy file contents:"
cat "$POLICY_FULL_FILE_PATH="

echo "4. Creating policy $POLICY_NAME from file $POLICY_FILE"
# 4. Создать политику в MinIO
docker_mc admin policy create "$ALIAS_NAME" "$POLICY_NAME" "${POLICY_FILE}"

echo "4. Attaching policy $POLICY_NAME to user $ACCESS_KEY"
# 5. Привязать политику к пользователю outline-user
docker_mc admin policy attach "$ALIAS_NAME" "$POLICY_NAME" --user "$ACCESS_KEY"
echo "Done!"

echo "Current user list:"
docker_mc admin user list "$ALIAS_NAME"

