-- Rode no Supabase: SQL Editor > New query > Run
--
-- ATENÇÃO: as duas linhas abaixo APAGAM as tabelas antigas (e os dados de teste
-- que estiverem nelas). Estão aí porque a versão anterior deste projeto usava
-- outro formato de "tarefas". Se você não quer perder nada, remova essas linhas.
drop table if exists public.realizacoes;
drop table if exists public.tarefas;

-- Tarefas cadastradas: nome + cor.
-- "arquivada" esconde a tarefa do dia a dia sem perder o histórico dela.
create table public.tarefas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 60),
  cor text not null default '#2563eb' check (cor ~ '^#[0-9a-fA-F]{6}$'),
  -- A cada quantos dias a tarefa deveria ser feita (7 = semanal). Nulo = sem frequência.
  frequencia_dias integer check (frequencia_dias between 1 and 365),
  arquivada boolean not null default false,
  criada_em timestamptz not null default now()
);

-- Tarefas realizadas: qual tarefa foi feita em qual dia.
-- O par (tarefa_id, dia) é único: não dá para marcar a mesma tarefa 2x no mesmo dia.
create table public.realizacoes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tarefa_id uuid not null references public.tarefas(id) on delete cascade,
  dia date not null,
  unique (tarefa_id, dia)
);

create index realizacoes_user_dia_idx on public.realizacoes (user_id, dia desc);

alter table public.tarefas enable row level security;
alter table public.realizacoes enable row level security;

-- tarefas: cada pessoa só enxerga e mexe nas próprias
create policy "ver proprias tarefas" on public.tarefas
  for select to authenticated using (user_id = (select auth.uid()));
create policy "criar proprias tarefas" on public.tarefas
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "editar proprias tarefas" on public.tarefas
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "apagar proprias tarefas" on public.tarefas
  for delete to authenticated using (user_id = (select auth.uid()));

-- realizacoes: idem, e só dá para marcar tarefa que é sua
create policy "ver proprias realizacoes" on public.realizacoes
  for select to authenticated using (user_id = (select auth.uid()));
create policy "criar proprias realizacoes" on public.realizacoes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.tarefas t where t.id = tarefa_id and t.user_id = (select auth.uid()))
  );
create policy "apagar proprias realizacoes" on public.realizacoes
  for delete to authenticated using (user_id = (select auth.uid()));
