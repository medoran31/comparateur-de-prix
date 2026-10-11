-- =====================================================================
-- CORRECTIONS RLS issues de l'audit du 11/10/2026
-- =====================================================================
-- 1) category_options : RLS activee mais AUCUNE politique -> table
--    totalement inaccessible. L'ecran "options produit" du marchand
--    affichait donc une liste vide alors que 35 options existent.
-- 2) merchants : un marchand pouvait modifier TOUTES les colonnes de sa
--    fiche, y compris `status` (se reactiver apres une suspension) et
--    `trial_end` (prolonger indefiniment son essai gratuit).
-- 3) products : la lecture anonyme exposait aussi les produits inactifs.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) category_options : lecture publique + gestion par l'admin
-- ---------------------------------------------------------------------
alter table public.category_options enable row level security;

drop policy if exists "lecture publique des options" on public.category_options;
create policy "lecture publique des options"
  on public.category_options
  for select
  to anon, authenticated
  using (active = true);

drop policy if exists "admin gere les options" on public.category_options;
create policy "admin gere les options"
  on public.category_options
  for all
  to authenticated
  using (public.est_admin())
  with check (public.est_admin());

-- ---------------------------------------------------------------------
-- 2) merchants : proteger les colonnes sensibles
--    Un marchand ne peut modifier que ses informations de contact et sa
--    position. `status`, `trial_end`, `user_id`, `id`, `created_at` sont
--    reserves a l'administrateur.
--    (Le contexte serveur — SQL Editor, service_role — n'est pas bloque.)
-- ---------------------------------------------------------------------
create or replace function public.proteger_colonnes_marchand()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Pas de session utilisateur (SQL Editor, service_role, migration) :
  -- on laisse passer, seuls les clients de l'application sont encadres.
  if auth.uid() is null then
    return new;
  end if;

  -- L'administrateur peut tout modifier.
  if public.est_admin() then
    return new;
  end if;

  if new.user_id    is distinct from old.user_id
     or new.status     is distinct from old.status
     or new.trial_end  is distinct from old.trial_end
     or new.id         is distinct from old.id
     or new.created_at is distinct from old.created_at then
    raise exception
      'Modification non autorisee : un marchand ne peut modifier que ses coordonnees.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_proteger_colonnes_marchand on public.merchants;
create trigger trg_proteger_colonnes_marchand
  before update on public.merchants
  for each row
  execute function public.proteger_colonnes_marchand();

-- ---------------------------------------------------------------------
-- 3) products : ne plus exposer les produits inactifs aux visiteurs
-- ---------------------------------------------------------------------
drop policy if exists "lecture publique des produits" on public.products;
create policy "lecture publique des produits"
  on public.products
  for select
  to anon
  using (active = true);

-- Rechargement du cache de PostgREST (prise en compte des nouvelles
-- definitions cote API).
notify pgrst, 'reload schema';
