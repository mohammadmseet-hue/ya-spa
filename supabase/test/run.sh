#!/usr/bin/env bash
# Verify the Ya Spa backend (0001 + 0002) on a throwaway Postgres:
#   security-authoritative pricing, no-direct-write, cross-user isolation,
#   anti-double-booking, owner/admin access, cancel cutoff.
# Usage: supabase/test/run.sh   (needs docker)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # supabase/
C=yaspa_pg_test
PASS=0; FAIL=0
ok(){   echo "  PASS  $1"; PASS=$((PASS+1)); }
bad(){  echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

psqlc(){ docker exec -i "$C" psql -U postgres -d yaspa -v ON_ERROR_STOP=1 -tA "$@" 2>&1; }
# run SQL as a simulated authenticated user (uid = $1). -q + SET keep stdout to
# ONLY the final query's rows (so captured values aren't polluted by SET/echo).
as_user(){ local uid="$1"; shift
  docker exec -i "$C" psql -U postgres -d yaspa -tA -q \
    -c "set role authenticated" -c "set test.uid = '$uid'" -c "$1" 2>&1; }

echo "==> starting postgres"
docker rm -f "$C" >/dev/null 2>&1
docker run -d --name "$C" -e POSTGRES_PASSWORD=pg -e POSTGRES_DB=yaspa postgres:16 >/dev/null
# Wait for the REAL server (postgres restarts after first-boot initdb, so a
# trivial query must actually succeed before we load anything).
ready=0
for i in $(seq 1 60); do
  if docker exec "$C" psql -U postgres -d yaspa -tAc 'select 1' >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo "postgres never became ready"; docker logs "$C" | tail; docker rm -f "$C">/dev/null; exit 1; }

echo "==> loading shim + migrations"
psqlc < "$HERE/test/00_shim.sql"        >/dev/null || { echo "shim failed"; docker logs "$C" | tail; exit 1; }
if ! psqlc < "$HERE/migrations/0001_init.sql" >/tmp/m1.log; then echo "0001 FAILED:"; cat /tmp/m1.log; docker rm -f "$C">/dev/null; exit 1; fi
if ! psqlc < "$HERE/migrations/0002_real_app.sql" >/tmp/m2.log; then echo "0002 FAILED:"; cat /tmp/m2.log; docker rm -f "$C">/dev/null; exit 1; fi
if ! psqlc < "$HERE/migrations/0003_catalog_extend.sql" >/tmp/m3.log; then echo "0003 FAILED:"; cat /tmp/m3.log; docker rm -f "$C">/dev/null; exit 1; fi
echo "  migrations applied cleanly"

# ---- seed identities ----
A="11111111-1111-1111-1111-111111111111"
B="22222222-2222-2222-2222-222222222222"
OWNER="99999999-9999-9999-9999-999999999999"
psqlc <<SQL >/dev/null
insert into auth.users(id,phone) values ('$A','+966500000001'),('$B','+966500000002'),('$OWNER','+966500000009');
insert into public.admins(user_id,label) values ('$OWNER','owner');
SQL

echo "==> tests"
SLOT="2027-03-01 15:00:00+03"

# T1 — server-authoritative pricing on create_booking (swedish 90m => price 280, total 357)
R=$(as_user "$A" "select price||'|'||total||'|'||status||'|'||payment_status from public.create_booking('swedish',90,'reem','$SLOT','King Rd','12','3','Al Shati','Jeddah',21.5,39.1,'firm please','on_arrival','Sara','+966500000001');")
echo "$R" | grep -q "280|357|pending|unpaid" && ok "create_booking computes price/total server-side, forces pending/unpaid ($R)" || bad "create_booking pricing/state ($R)"
BID=$(as_user "$A" "select id from public.bookings limit 1;")

# T2 — customer CANNOT insert a booking row directly (write path revoked)
R=$(as_user "$A" "insert into public.bookings(user_id,service_id,booking_date,booking_time,total) values ('$A','swedish','2027-03-02','15:00',0);")
echo "$R" | grep -qi "permission denied" && ok "direct INSERT into bookings is denied" || bad "direct insert not denied ($R)"

# T3 — customer CANNOT forge payment_status='paid' via direct UPDATE (the review bug — now closed)
R=$(as_user "$A" "update public.bookings set payment_status='paid', total=0 where user_id='$A';")
echo "$R" | grep -qi "permission denied" && ok "direct UPDATE (forge paid/total) is denied" || bad "forge-paid not denied ($R)"

# T4 — cross-user isolation: B cannot see A's booking
R=$(as_user "$B" "select count(*) from public.bookings;")
[ "$R" = "0" ] && ok "cross-user isolation: B sees 0 of A's bookings" || bad "isolation leak: B sees $R"

# T5 — anti-double-booking: B booking the same therapist+slot is rejected
R=$(as_user "$B" "select public.create_booking('deep',60,'reem','$SLOT','X','1','1','Y','Jeddah',21.5,39.1,'','on_arrival');")
echo "$R" | grep -qi "slot_taken" && ok "double-booking same therapist+slot rejected (slot_taken)" || bad "double-booking not rejected ($R)"

# T6 — cancel by non-owner is refused
R=$(as_user "$B" "select public.cancel_booking('$BID');")
echo "$R" | grep -qi "cancel_not_allowed" && ok "cancel_booking by non-owner refused" || bad "non-owner cancel not refused ($R)"

# T6b — booking WITHOUT a GPS pin (client omits p_lat/p_lng, as the Swift SDK does for nil)
R=$(as_user "$A" "select status from public.create_booking(p_service_id=>'foot',p_duration_min=>60,p_therapist_id=>'hind',p_scheduled_at=>'2027-05-01 12:00:00+03',p_address_line=>'King Rd',p_building=>'2',p_apartment=>'1',p_district=>'Al Shati',p_city=>'Jeddah',p_notes=>'no pin',p_payment_method=>'on_arrival',p_customer_name=>'Noura',p_contact_phone=>'+966500000003');")
echo "$R" | grep -qx "pending" && ok "booking without GPS pin (lat/lng omitted) succeeds" || bad "no-pin booking failed ($R)"

# T7 — invalid duration is rejected (only 60/90/120 priced)
R=$(as_user "$A" "select public.create_booking('swedish',75,'hind','2027-04-01 12:00:00+03','X','1','1','Y','Jeddah',1,1,'','on_arrival');")
echo "$R" | grep -qi "invalid_duration" && ok "invalid duration (75m) rejected" || bad "invalid duration not rejected ($R)"

# T8 — taken_slots returns ONLY the time (no PII), for the booked therapist/date
R=$(as_user "$B" "select count(*)||'/'||string_agg(booking_time,',') from public.taken_slots('reem','2027-03-01');")
echo "$R" | grep -q "1/15:00" && ok "taken_slots returns booked time only ($R)" || bad "taken_slots wrong ($R)"

# T9 — owner sees ALL orders; non-admin cannot drive status; owner can
R=$(as_user "$OWNER" "select count(*) from public.bookings;")
[ "$R" -ge 1 ] 2>/dev/null && ok "owner/admin sees all orders ($R)" || bad "owner cannot see orders ($R)"
# owner sees the customer contact captured at booking time (name + phone for navigation/call)
R=$(as_user "$OWNER" "select customer_name||'/'||contact_phone from public.bookings where id='$BID';")
echo "$R" | grep -qx "Sara/+966500000001" && ok "owner sees customer name + phone ($R)" || bad "owner missing customer contact ($R)"
R=$(as_user "$A" "select public.admin_set_status('$BID','confirmed');")
echo "$R" | grep -qi "forbidden" && ok "non-admin admin_set_status forbidden" || bad "non-admin drove status ($R)"
R=$(as_user "$OWNER" "select status from public.admin_set_status('$BID','confirmed');")
echo "$R" | grep -qx "confirmed" && ok "owner drives order to confirmed" || bad "owner set_status failed ($R)"

# T10 — audit trail recorded the lifecycle
R=$(as_user "$OWNER" "select count(*) from public.booking_events where booking_id='$BID';")
[ "$R" -ge 2 ] 2>/dev/null && ok "booking_events audit trail recorded ($R events)" || bad "audit trail missing ($R)"

# T11 — owner cancel path frees slot; then A can rebook the slot (reschedule/availability sane)
as_user "$OWNER" "select public.admin_set_status('$BID','cancelled');" >/dev/null
R=$(as_user "$A" "select status from public.create_booking('aroma',60,'reem','$SLOT','King Rd','12','3','Al Shati','Jeddah',21.5,39.1,'','on_arrival');")
echo "$R" | grep -qx "pending" && ok "slot re-bookable after cancellation (index predicate correct)" || bad "slot not freed after cancel ($R)"

echo "==================================================="
echo "  PASS=$PASS  FAIL=$FAIL"
docker rm -f "$C" >/dev/null 2>&1
[ "$FAIL" = "0" ]
