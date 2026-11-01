-- Use este arquivo SE VOCÊ JÁ RODOU o schema.sql antes (não apaga nada).
-- Se ainda não rodou o schema.sql, ignore este arquivo: o schema.sql já inclui esta coluna.
--
-- Rode no Supabase: SQL Editor > New query > Run

alter table public.tarefas
  add column if not exists frequencia_dias integer
  check (frequencia_dias between 1 and 365);
