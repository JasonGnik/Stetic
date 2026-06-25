-- Consistency cache. The same photo set + sex should always return the same score:
-- Gemini drifts run-to-run even at temperature 0, so we key results by a stable hash
-- of the (normalized) photo bytes + sex and return the stored card on a repeat scan.
-- A genuinely new photo (new lighting/pump/angle) hashes differently → a fresh score.
alter table scans add column if not exists photo_hash text;
create index if not exists scans_user_hash_idx on scans (user_id, photo_hash);
