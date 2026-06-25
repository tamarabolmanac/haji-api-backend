# Sigurnost baze (Supabase)

Kratak pregled kako Hajki koristi bazu i šta je urađeno povodom Supabase
security upozorenja (`rls_disabled_in_public`, `sensitive_columns_exposed`).

## Kako se aplikacija kači na bazu

- Produkciona baza je **Supabase Postgres**.
- Rails se kači **direktno na Postgres** preko `DATABASE_URL` (port 5432,
  rola `postgres`, preko Supabase poolera). To je obična DB konekcija.
- Rola `postgres` je privilegovana i **zaobilazi RLS** (`BYPASSRLS`), pa
  aplikacija vidi sve i radi nezavisno od RLS podešavanja.
- Aplikacija **ne koristi** Supabase SDK ni Supabase „Data API" (nema
  `anon`/`service_role` ključeva u kodu).

## U čemu je bio problem

Supabase, pored direktne konekcije, automatski diže i **Data API (PostgREST)**
na `https://<projekat>.supabase.co/rest/v1/...`. Taj API izlaže tabele iz šema
navedenih u *Project Settings → API → Exposed schemas* (podrazumevano `public`)
rolama `anon` i `authenticated`, a `anon` ključ je po dizajnu javan.

Pošto je **RLS bio isključen** na tabelama u `public` šemi, bilo ko sa anon
ključem je mogao da čita/menja/briše sve tabele (uključujući `users` sa
`password_digest`) preko tog javnog HTTP API-ja — potpuno zaobilazeći Rails.

## Šta je urađeno

1. **Uklonjen `public` iz „Exposed schemas"** (*Project Settings → API*).
   Data API više ne izlaže nijednu tabelu preko javnog HTTP-a → glavna rupa
   zatvorena. Direktna Rails konekcija je netaknuta (radi na drugom sloju).
2. **(Preporuka) Rotirati lozinku baze** (*Database → Reset database password*),
   pa ažurirati `DATABASE_URL` i redeplojovati — lozinka je stajala u plaintextu
   u `.env`.

## Opcioni „defense-in-depth" — uključi RLS na svim tabelama

Nije nužno pošto Data API više ne izlaže `public`, ali ne škodi (aplikacija i
dalje radi jer `postgres` rola zaobilazi RLS). Pokrenuti u **Supabase SQL Editor**:

```sql
-- Uključi RLS na svim tabelama u public (bez politika = anon/authenticated ne dobijaju ništa)
do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security;', r.tablename);
  end loop;
end $$;

-- Oduzmi pristup API rolama (pojas i tregeri)
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
```

## Pojmovnik

- **RLS (Row-Level Security):** Postgres mehanizam koji filtrira redove po
  politikama. RLS uključen bez politika = rola ne dobija ništa. Privilegovane
  role (`postgres`) ga zaobilaze.
- **Schema:** imenik/grupa tabela unutar baze. `public` je podrazumevana šema
  gde su sve tabele aplikacije.
- **Data API / PostgREST:** automatski HTTP sloj koji Supabase diže iznad baze;
  odvojen od direktne DB konekcije koju koristi Rails.
