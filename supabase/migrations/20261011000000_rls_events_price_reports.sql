-- =====================================================================
-- AS3AR - Politiques RLS pour les statistiques et les signalements
-- =====================================================================
-- Contexte
-- --------
-- Les tables `events` (statistiques du marchand) et `price_reports`
-- (boutons "Confirme / Faux") disposaient deja de politiques d'ECRITURE
-- pour les roles `anon` et `authenticated`. En revanche il manquait :
--   * une politique de LECTURE pour l'administrateur sur les deux tables ;
--   * une politique de LECTURE pour le marchand sur `price_reports`.
--
-- Consequences avant correction :
--   * le tableau de bord marchand ne pouvait pas lire ses signalements ;
--   * la page d'administration ne pouvait pas agreger les statistiques.
--
-- Cette migration ajoute les politiques manquantes et les fonctions
-- utilitaires necessaires. Elle est idempotente (rejouable sans risque).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Fonctions utilitaires
--    `security definer` permet de verifier l'appartenance sans etre
--    bloque par les politiques RLS des tables interrogees.
-- ---------------------------------------------------------------------
create or replace function public.est_mon_marchand(p_merchant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.merchants m
    where m.id = p_merchant_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.est_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles r
    where r.user_id = auth.uid()
      and r.role = 'admin'
  );
$$;

grant execute on function public.est_mon_marchand(uuid) to anon, authenticated;
grant execute on function public.est_admin() to anon, authenticated;

-- ---------------------------------------------------------------------
-- 2) Table events
--    (les politiques d'ecriture `anon` / `authenticated` existent deja)
-- ---------------------------------------------------------------------
alter table public.events enable row level security;

-- L'administrateur peut lire toutes les statistiques
drop policy if exists "events_select_admin" on public.events;
create policy "events_select_admin"
  on public.events
  for select
  to authenticated
  using (public.est_admin());

-- ---------------------------------------------------------------------
-- 3) Table price_reports
--    (les politiques d'ecriture `anon` / `authenticated` existent deja)
-- ---------------------------------------------------------------------
alter table public.price_reports enable row level security;

-- Le marchand lit les signalements portant sur ses propres prix
drop policy if exists "reports_select_marchand" on public.price_reports;
create policy "reports_select_marchand"
  on public.price_reports
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.prices p
      where p.id = price_reports.price_id
        and public.est_mon_marchand(p.merchant_id)
    )
  );

-- L'administrateur lit tous les signalements
drop policy if exists "reports_select_admin" on public.price_reports;
create policy "reports_select_admin"
  on public.price_reports
  for select
  to authenticated
  using (public.est_admin());
