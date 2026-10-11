-- =====================================================================
-- Nettoyage : suppression des fonctions d'audit temporaires
-- (elles exposaient l'inventaire des politiques RLS et le code des
--  fonctions a la cle publique : a ne pas laisser en production).
-- =====================================================================
drop function if exists public.audit_rls();
drop function if exists public.audit_fonctions();
