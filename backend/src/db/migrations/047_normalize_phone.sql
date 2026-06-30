-- 047_normalize_phone.sql
-- Normalize existing Indian phone numbers to canonical +91XXXXXXXXXX form so
-- they match the customer-portal login (which always queries with +91).
--
-- Covers numbers stored with or without +91, with spaces/dashes, a leading 0,
-- or a bare 10-digit number. Anything that is not a valid >=10-digit mobile is
-- left untouched. Idempotent: re-running produces no further changes.

-- Session-temporary helper (auto-dropped at end of session).
CREATE OR REPLACE FUNCTION pg_temp.norm_phone(raw text) RETURNS text AS $$
DECLARE
  d text;
BEGIN
  IF raw IS NULL THEN
    RETURN NULL;
  END IF;
  d := regexp_replace(raw, '[^0-9]', '', 'g');
  IF length(d) < 10 THEN
    RETURN raw; -- not a normal mobile number — leave as-is
  END IF;
  RETURN '+91' || right(d, 10);
END;
$$ LANGUAGE plpgsql;

-- projects: general contact + legacy customer auth columns
UPDATE projects SET
  phone               = pg_temp.norm_phone(phone),
  alt_phone           = pg_temp.norm_phone(alt_phone),
  customer_mobile     = pg_temp.norm_phone(customer_mobile),
  customer_mobile_alt = pg_temp.norm_phone(customer_mobile_alt)
WHERE phone               IS DISTINCT FROM pg_temp.norm_phone(phone)
   OR alt_phone           IS DISTINCT FROM pg_temp.norm_phone(alt_phone)
   OR customer_mobile     IS DISTINCT FROM pg_temp.norm_phone(customer_mobile)
   OR customer_mobile_alt IS DISTINCT FROM pg_temp.norm_phone(customer_mobile_alt);

-- customers: alternate number first (no unique constraint)
UPDATE customers SET
  mobile_alt = pg_temp.norm_phone(mobile_alt)
WHERE mobile_alt IS DISTINCT FROM pg_temp.norm_phone(mobile_alt);

-- customers.mobile is UNIQUE — only normalize when it will not collide with
-- another existing row (those rare duplicates are left for manual review).
UPDATE customers c SET
  mobile = pg_temp.norm_phone(c.mobile)
WHERE c.mobile IS DISTINCT FROM pg_temp.norm_phone(c.mobile)
  AND NOT EXISTS (
    SELECT 1 FROM customers c2
    WHERE c2.id <> c.id
      AND c2.mobile = pg_temp.norm_phone(c.mobile)
  );
