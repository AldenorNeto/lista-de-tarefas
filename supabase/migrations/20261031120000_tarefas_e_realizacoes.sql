-- Cria as tabelas do app de tarefas. Não apaga dados: pode ser aplicada mais de uma vez.

-- Trava de segurança: se existir a tabela "tarefas" no formato da primeira versão do app
-- (com a coluna "titulo"), para aqui em vez de apagar qualquer coisa.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tarefas' and column_name = 'titulo'
  ) then
    raise exception 'public.tarefas está no formato antigo (coluna "titulo"). Apague essa tabela manualmente se não tiver dados importantes e rode de novo.';
  end if;
end $$;

-- Tarefas cadastradas: nome + cor + frequência opcional.
create table if not exists public.tarefas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome text not null check (char_length(nome) between 1 and 60),
  cor text not null default '#2563eb' check (cor ~ '^#[0-9a-fA-F]{6}$'),
  frequencia_dias integer check (frequencia_dias between 1 and 365),
  arquivada boolean not null default false,
  criada_em timestamptz not null default now()
);

-- Cobre quem já tinha criado a tabela sem a coluna de frequência.
alter table public.tarefas
  add column if not exists frequencia_dias integer check (frequencia_dias between 1 and 365);

-- Tarefas realizadas: qual tarefa foi feita em qual dia (o par é único).
create table if not exists public.realizacoes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tarefa_id uuid not null references public.tarefas(id) on delete cascade,
  dia date not null,
  unique (tarefa_id, dia)
);

create index if not exists realizacoes_user_dia_idx on public.realizacoes (user_id, dia desc);

alter table public.tarefas enable row level security;
alter table public.realizacoes enable row level security;

-- Regras de acesso (recriadas a cada aplicação; só mexem em policies, nunca em dados).
drop policy if exists "ver proprias tarefas" on public.tarefas;
drop policy if exists "criar proprias tarefas" on public.tarefas;
drop policy if exists "editar proprias tarefas" on public.tarefas;
drop policy if exists "apagar proprias tarefas" on public.tarefas;
drop policy if exists "ver proprias realizacoes" on public.realizacoes;
drop policy if exists "criar proprias realizacoes" on public.realizacoes;
drop policy if exists "apagar proprias realizacoes" on public.realizacoes;

create policy "ver proprias tarefas" on public.tarefas
  for select to authenticated using (user_id = (select auth.uid()));
create policy "criar proprias tarefas" on public.tarefas
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "editar proprias tarefas" on public.tarefas
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "apagar proprias tarefas" on public.tarefas
  for delete to authenticated using (user_id = (select auth.uid()));

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
