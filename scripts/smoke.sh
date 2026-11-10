#!/usr/bin/env bash
# End-to-end smoke test against a running stack (`make up`).
# Exercises: auth, submission, async ML scoring, decision policy, officer org-scoping,
# status transition guard, and the 0–1000 ml_score scale.
#
# Uses the demo accounts seeded by the BranchesAndDataPool migration
# (client1 belongs to the same organization as officer1, not officer2).
set -euo pipefail

API="${API:-http://localhost:3000/api/v1.0}"
ML="${ML:-http://localhost:7860}"
APPLICANT_EMAIL="${APPLICANT_EMAIL:-client1@nivuba.test}"
APPLICANT_PASSWORD="${APPLICANT_PASSWORD:-Applicant@123456!}"
OFFICER_PASSWORD="${OFFICER_PASSWORD:-Officer@123456!}"
ADMIN_EMAIL="${ADMIN_EMAIL:-platform-admin@nivuba.test}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-${SEED_ADMIN_PASSWORD:-Admin@123456!}}"
TIMEOUT="${TIMEOUT:-90}"

pass=0
ok()   { pass=$((pass + 1)); printf '  \033[32m✔\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘ %s\033[0m\n' "$*" >&2; exit 1; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# req METHOD PATH [TOKEN] [JSON] -> prints body, sets $STATUS
req() {
  local method=$1 path=$2 token=${3:-} body=${4:-} out
  out=$(mktemp)
  local args=(-s -o "$out" -w '%{http_code}' -X "$method" "$API$path" -H 'Content-Type: application/json')
  [[ -n $token ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n $body ]] && args+=(-d "$body")
  STATUS=$(curl "${args[@]}")
  BODY=$(cat "$out"); rm -f "$out"
}
expect() { [[ $STATUS == "$1" ]] || fail "$2: expected HTTP $1, got $STATUS — $BODY"; ok "$2 (HTTP $STATUS)"; }
login() {
  req POST /auth/login "" "{\"email\":\"$1\",\"password\":\"$2\"}"
  [[ $STATUS == 200 || $STATUS == 201 ]] || fail "login $1: HTTP $STATUS — $BODY"
  jq -r .accessToken <<<"$BODY"
}

step "Health"
curl -fsS "$ML/health" >/dev/null || fail "ML /health unreachable at $ML"; ok "ML service healthy"
req GET /health; expect 200 "core /health"

step "Applicant submits a loan"
APPLICANT=$(login "$APPLICANT_EMAIL" "$APPLICANT_PASSWORD"); ok "applicant logged in"
req POST /loan-applications "$APPLICANT" '{"requestedAmount":1200,"termMonths":12}'
expect 201 "submit application"
LOAN_ID=$(jq -r .id <<<"$BODY")
[[ $(jq -r .status <<<"$BODY") == PENDING ]] || fail "new application should be PENDING"; ok "created $LOAN_ID as PENDING"

req POST /loan-applications "$APPLICANT" '{"requestedAmount":-5,"termMonths":0}'
expect 400 "invalid payload rejected"

step "Asynchronous ML scoring"
deadline=$((SECONDS + TIMEOUT))
while :; do
  req GET "/loan-applications/$LOAN_ID" "$APPLICANT"
  status=$(jq -r .status <<<"$BODY"); score=$(jq -r .mlScore <<<"$BODY")
  [[ $score != null ]] && break
  (( SECONDS > deadline )) && fail "not scored within ${TIMEOUT}s (status=$status)"
  sleep 2
done
ok "scored: status=$status mlScore=$score"
jq -e '.mlScore | type == "number" and . == floor and . >= 0 and . <= 1000' <<<"$BODY" >/dev/null \
  || fail "mlScore must be an integer 0–1000, got $score"; ok "mlScore is an integer in 0–1000"
[[ $status =~ ^(APPROVED|REJECTED|UNDER_REVIEW)$ ]] || fail "unexpected status $status"
reason=$(jq -r .decisionReason <<<"$BODY")
[[ $reason =~ ^(Approved|Rejected|Manual\ review) ]] || fail "decisionReason missing/unexpected: $reason"; ok "decisionReason: $reason"
if [[ $status == APPROVED ]]; then
  jq -e '(.approvedAmount | tonumber) == 1200' <<<"$BODY" >/dev/null || fail "approvedAmount should equal requested"; ok "approvedAmount set"
fi

step "Organization scoping"
OFFICER1=$(login officer1@nivuba.test "$OFFICER_PASSWORD"); ok "officer1 logged in"
OFFICER2=$(login officer2@nivuba.test "$OFFICER_PASSWORD"); ok "officer2 logged in"
req GET /loan-applications "$OFFICER1"; expect 200 "officer1 lists applications"
jq -e --arg id "$LOAN_ID" 'any(.[]; .id == $id)' <<<"$BODY" >/dev/null || fail "officer1 should see the new loan"
[[ $(jq '[.[].organizationId] | unique | length' <<<"$BODY") == 1 ]] || fail "officer1 sees several organizations"
ok "officer1 sees only one organization ($(jq length <<<"$BODY") applications)"
req GET "/loan-applications/$LOAN_ID" "$OFFICER2"; expect 404 "officer2 cannot read another org's loan"
req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER2" '{"status":"CANCELLED"}'
expect 404 "officer2 cannot change another org's loan"
req GET /users "$OFFICER1"
[[ $(jq '[.[].organizationId] | unique | length' <<<"$BODY") == 1 ]] || fail "officer1 /users leaks other orgs"; ok "officer1 /users scoped"
req POST /loan-applications "$OFFICER1" '{"requestedAmount":100,"termMonths":1}'
expect 403 "officers cannot submit applications"

step "Status transition guard"
req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER1" "{\"status\":\"$status\"}"
expect 400 "$status -> $status is refused"
case $status in
  REJECTED) next=UNDER_REVIEW ;;
  *)        next=CANCELLED ;;
esac
req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER1" "{\"status\":\"$next\",\"decisionReason\":\"smoke test\"}"
expect 200 "$status -> $next allowed"
if [[ $next == UNDER_REVIEW ]]; then
  req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER1" '{"status":"APPROVED","approvedAmount":5000}'
  expect 400 "approvedAmount above requested is refused"
  req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER1" '{"status":"APPROVED","approvedAmount":1000}'
  expect 200 "manual approval with partial amount"
  jq -e '(.approvedAmount | tonumber) == 1000' <<<"$BODY" >/dev/null || fail "approvedAmount not stored"; ok "approvedAmount=1000 stored"
  req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER1" '{"status":"CANCELLED"}'; expect 200 "APPROVED -> CANCELLED allowed"
fi
req PATCH "/loan-applications/$LOAN_ID/status" "$OFFICER1" '{"status":"APPROVED"}'
expect 400 "CANCELLED is final"

step "Score scale of existing data"
ADMIN=$(login "$ADMIN_EMAIL" "$ADMIN_PASSWORD"); ok "admin logged in"
req GET /loan-applications "$ADMIN"; expect 200 "admin lists all applications"
jq -e 'all(.[]; .mlScore == null or (.mlScore | type == "number" and . == floor and . >= 0 and . <= 1000))' <<<"$BODY" >/dev/null \
  || fail "some ml_score values are not integers in 0–1000"
[[ $(jq '[.[].organizationId] | unique | length' <<<"$BODY") -gt 1 ]] || fail "admin should see several organizations"
ok "all $(jq length <<<"$BODY") applications use the 0–1000 scale; admin sees all orgs"

printf '\n\033[32mSmoke test passed (%d checks).\033[0m\n' "$pass"
