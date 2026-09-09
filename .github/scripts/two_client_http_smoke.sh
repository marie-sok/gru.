#!/usr/bin/env bash
set -euo pipefail

BASE="${GRU_SMOKE_BASE_URL:-http://127.0.0.1:8081}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

json_post() {
  local path="$1" token="$2" body="$3"
  local args=(--fail --silent --show-error -X POST "$BASE$path" -H 'Content-Type: application/json' -H 'Accept: application/json' --data "$body")
  if [[ -n "$token" ]]; then
    args+=( -H "Authorization: Bearer $token" )
  fi
  curl "${args[@]}"
}

register_user() {
  local phone="$1" nickname="$2"
  jq -nc --arg phone "$phone" --arg password 'ci-password-123!' --arg nickname "$nickname" \
    '{phone:$phone,password:$password,nickname:$nickname}' \
    | curl --fail --silent --show-error \
        -X POST "$BASE/auth/register" \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json' \
        --data-binary @-
}

raw_public_key_b64() {
  local private_key="$1"
  openssl pkey -in "$private_key" -pubout -outform DER 2>/dev/null \
    | tail -c 32 \
    | base64 -w0
}

fingerprint() {
  printf '%s' "$1" | base64 -d | sha256sum | awk '{print $1}'
}

sign_ed25519() {
  local private_key="$1" payload="$2"
  printf '%s' "$payload" \
    | openssl pkeyutl -sign -rawin -inkey "$private_key" 2>/dev/null \
    | base64 -w0
}

make_identity() {
  local name="$1"
  openssl genpkey -algorithm X25519 -out "$TMP/${name}-x25519.pem" 2>/dev/null
  openssl genpkey -algorithm ED25519 -out "$TMP/${name}-ed25519.pem" 2>/dev/null
}

publish_identity() {
  local name="$1" token="$2"
  local agreement signing body
  agreement="$(raw_public_key_b64 "$TMP/${name}-x25519.pem")"
  signing="$(raw_public_key_b64 "$TMP/${name}-ed25519.pem")"
  body="$(jq -nc --arg agreement "$agreement" --arg signing "$signing" \
    '{keyAgreementPublicKey:$agreement,signingPublicKey:$signing}')"

  curl --fail --silent --show-error \
    -X PUT "$BASE/e2ee/keys/me" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    --data "$body" >/dev/null
}

send_v2() {
  local name="$1" sender_id="$2" receiver_id="$3" token="$4" chat_id="$5" marker="$6"
  local client_id recipient_ephemeral recovery_ephemeral recipient_cipher recovery_cipher signing_pub fp canonical sig body

  client_id="$(cat /proc/sys/kernel/random/uuid)"
  recipient_ephemeral="$(openssl rand 32 | base64 -w0)"
  recovery_ephemeral="$(openssl rand 32 | base64 -w0)"
  recipient_cipher="$(printf 'recipient:%s:%s' "$marker" "$client_id" | base64 -w0)"
  recovery_cipher="$(printf 'sender-recovery:%s:%s' "$marker" "$client_id" | base64 -w0)"
  signing_pub="$(raw_public_key_b64 "$TMP/${name}-ed25519.pem")"
  fp="$(fingerprint "$signing_pub")"

  canonical="gru-e2ee-v2|${chat_id}|${sender_id}|${receiver_id}|${client_id}|${recipient_ephemeral}|${recipient_cipher}|${recovery_ephemeral}|${recovery_cipher}|${fp}"
  sig="$(sign_ed25519 "$TMP/${name}-ed25519.pem" "$canonical")"

  body="$(jq -nc \
    --arg chatId "$chat_id" \
    --arg clientMessageId "$client_id" \
    --arg encryptedPayload "$recipient_cipher" \
    --arg senderEphemeralPublicKey "$recipient_ephemeral" \
    --arg senderRecoveryEncryptedPayload "$recovery_cipher" \
    --arg senderRecoveryEphemeralPublicKey "$recovery_ephemeral" \
    --arg signature "$sig" \
    --arg senderKeyFingerprint "$fp" \
    '{
      chatId:$chatId,
      clientMessageId:$clientMessageId,
      encryptedPayload:$encryptedPayload,
      encryptionVersion:"gru-e2ee-v2",
      senderEphemeralPublicKey:$senderEphemeralPublicKey,
      senderRecoveryEncryptedPayload:$senderRecoveryEncryptedPayload,
      senderRecoveryEphemeralPublicKey:$senderRecoveryEphemeralPublicKey,
      signature:$signature,
      senderKeyFingerprint:$senderKeyFingerprint
    }')"

  json_post '/messages/e2ee' "$token" "$body"
}

suffix="$(date +%s)-$RANDOM"
alice_json="$(register_user "+1555100${RANDOM}" "ci-alice-$suffix")"
bob_json="$(register_user "+1555200${RANDOM}" "ci-bob-$suffix")"
charlie_json="$(register_user "+1555300${RANDOM}" "ci-charlie-$suffix")"

alice_token="$(jq -r '.token' <<<"$alice_json")"
alice_id="$(jq -r '.userId' <<<"$alice_json")"
bob_token="$(jq -r '.token' <<<"$bob_json")"
bob_id="$(jq -r '.userId' <<<"$bob_json")"
charlie_token="$(jq -r '.token' <<<"$charlie_json")"

for value in "$alice_token" "$alice_id" "$bob_token" "$bob_id" "$charlie_token"; do
  [[ -n "$value" && "$value" != "null" ]]
done

make_identity alice
make_identity bob
publish_identity alice "$alice_token"
publish_identity bob "$bob_token"

chat_body="$(jq -nc --arg userId "$bob_id" '{userId:$userId}')"
chat_json="$(json_post '/chats' "$alice_token" "$chat_body")"
chat_id="$(jq -r '.id' <<<"$chat_json")"
[[ -n "$chat_id" && "$chat_id" != "null" ]]

alice_message="$(send_v2 alice "$alice_id" "$bob_id" "$alice_token" "$chat_id" 'A-to-B')"
bob_message="$(send_v2 bob "$bob_id" "$alice_id" "$bob_token" "$chat_id" 'B-to-A')"

jq -e --arg sender "$alice_id" --arg receiver "$bob_id" '
  .senderId == $sender and
  .receiverId == $receiver and
  .text == "" and
  .encryptionVersion == "gru-e2ee-v2" and
  (.senderRecoveryEncryptedPayload | length > 0) and
  (.senderRecoveryEphemeralPublicKey | length > 0)
' <<<"$alice_message" >/dev/null

jq -e --arg sender "$bob_id" --arg receiver "$alice_id" '
  .senderId == $sender and
  .receiverId == $receiver and
  .text == "" and
  .encryptionVersion == "gru-e2ee-v2" and
  (.senderRecoveryEncryptedPayload | length > 0) and
  (.senderRecoveryEphemeralPublicKey | length > 0)
' <<<"$bob_message" >/dev/null

alice_history="$(curl --fail --silent --show-error \
  "$BASE/chats/$chat_id/messages" \
  -H "Authorization: Bearer $alice_token" \
  -H 'Accept: application/json')"
bob_history="$(curl --fail --silent --show-error \
  "$BASE/chats/$chat_id/messages" \
  -H "Authorization: Bearer $bob_token" \
  -H 'Accept: application/json')"

jq -e 'length == 2 and all(.[]; .text == "" and .encryptionVersion == "gru-e2ee-v2")' <<<"$alice_history" >/dev/null
jq -e 'length == 2 and all(.[]; .text == "" and .encryptionVersion == "gru-e2ee-v2")' <<<"$bob_history" >/dev/null

# A third authenticated account must not be able to enumerate the A/B history.
status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  "$BASE/chats/$chat_id/messages" \
  -H "Authorization: Bearer $charlie_token")"
[[ "$status" == "403" ]]

# A third authenticated account must not be able to enumerate Alice's E2EE identity.
status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  "$BASE/e2ee/keys/$alice_id" \
  -H "Authorization: Bearer $charlie_token")"
[[ "$status" == "403" || "$status" == "404" ]]

# Authenticated stale clients must fail closed rather than storing plaintext.
plaintext_body="$(jq -nc --arg chatId "$chat_id" --arg text 'must never persist' '{chatId:$chatId,text:$text}')"
status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  -X POST "$BASE/messages" \
  -H "Authorization: Bearer $alice_token" \
  -H 'Content-Type: application/json' \
  --data "$plaintext_body")"
[[ "$status" == "426" ]]

history_after_downgrade="$(curl --fail --silent --show-error \
  "$BASE/chats/$chat_id/messages" \
  -H "Authorization: Bearer $alice_token")"
jq -e 'length == 2 and all(.[]; .text == "")' <<<"$history_after_downgrade" >/dev/null

echo "PASS: live HTTP A↔B E2EE v2, history, metadata authz and plaintext downgrade gate"
