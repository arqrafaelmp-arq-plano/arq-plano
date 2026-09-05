-- ============================================================
--  ARQ-PLANO — Schema inicial do banco
--  Cole este arquivo inteiro no SQL Editor do Supabase e rode.
--  Seguro rodar mais de uma vez (usa IF NOT EXISTS / OR REPLACE).
-- ============================================================


-- ------------------------------------------------------------
-- 1. FUNÇÃO AUXILIAR: identifica o administrador
-- ------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'arqrafaelmp@gmail.com';
$$;


-- ------------------------------------------------------------
-- 2. TABELA: profiles (dados da empresa de cada usuário)
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  email         text not null,
  company       text        default '',
  cnpj          text        default '',
  phone         text        default '',
  contact_email text        default '',
  address       text        default '',
  logo          text        default '',
  logo_w        integer     default 0,
  logo_h        integer     default 0,
  companies     jsonb       default '[]'::jsonb,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table public.profiles enable row level security;


-- ------------------------------------------------------------
-- 3. TABELA: projects (as obras)
-- ------------------------------------------------------------
create table if not exists public.projects (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  type       text not null    default 'reforma',
  client     text             default '',
  address    text             default '',
  start_date date,
  status     text             default 'planejamento',
  logo       text             default '',
  logo_w     integer          default 0,
  logo_h     integer          default 0,
  phases     jsonb not null   default '[]'::jsonb,
  created_at timestamptz      default now(),
  updated_at timestamptz      default now()
);

create index if not exists projects_user_id_idx    on public.projects (user_id);
create index if not exists projects_created_at_idx on public.projects (created_at desc);

alter table public.projects enable row level security;


-- ------------------------------------------------------------
-- 4. POLÍTICAS DE SEGURANÇA — profiles
--    Cada usuário só enxerga o próprio perfil.
--    O administrador enxerga todos e pode excluir contas.
-- ------------------------------------------------------------
drop policy if exists "perfil: ler o proprio ou admin le todos" on public.profiles;
create policy "perfil: ler o proprio ou admin le todos"
  on public.profiles for select
  using (auth.uid() = id or public.is_admin());

drop policy if exists "perfil: criar o proprio" on public.profiles;
create policy "perfil: criar o proprio"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "perfil: atualizar o proprio" on public.profiles;
create policy "perfil: atualizar o proprio"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "perfil: admin exclui outros" on public.profiles;
create policy "perfil: admin exclui outros"
  on public.profiles for delete
  using (public.is_admin() and auth.uid() <> id);


-- ------------------------------------------------------------
-- 5. POLÍTICAS DE SEGURANÇA — projects
--    Cada usuário só acessa as próprias obras.
-- ------------------------------------------------------------
drop policy if exists "obras: ler as proprias ou admin le todas" on public.projects;
create policy "obras: ler as proprias ou admin le todas"
  on public.projects for select
  using (auth.uid() = user_id or public.is_admin());

drop policy if exists "obras: criar as proprias" on public.projects;
create policy "obras: criar as proprias"
  on public.projects for insert
  with check (auth.uid() = user_id);

drop policy if exists "obras: atualizar as proprias" on public.projects;
create policy "obras: atualizar as proprias"
  on public.projects for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "obras: excluir as proprias" on public.projects;
create policy "obras: excluir as proprias"
  on public.projects for delete
  using (auth.uid() = user_id);


-- ------------------------------------------------------------
-- 6. GATILHO: cria o perfil automaticamente no cadastro
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ------------------------------------------------------------
-- 7. GATILHO: mantém o campo updated_at em dia
-- ------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists projects_set_updated_at on public.projects;
create trigger projects_set_updated_at
  before update on public.projects
  for each row execute function public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- ------------------------------------------------------------
-- 8. STORAGE: bucket público para os logos das empresas
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('logos', 'logos', true)
on conflict (id) do nothing;

drop policy if exists "logos: qualquer um visualiza" on storage.objects;
create policy "logos: qualquer um visualiza"
  on storage.objects for select
  using (bucket_id = 'logos');

drop policy if exists "logos: usuario envia na propria pasta" on storage.objects;
create policy "logos: usuario envia na propria pasta"
  on storage.objects for insert
  with check (
    bucket_id = 'logos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "logos: usuario atualiza os proprios" on storage.objects;
create policy "logos: usuario atualiza os proprios"
  on storage.objects for update
  using (
    bucket_id = 'logos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "logos: usuario exclui os proprios" on storage.objects;
create policy "logos: usuario exclui os proprios"
  on storage.objects for delete
  using (
    bucket_id = 'logos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );


-- ------------------------------------------------------------
-- 9. COMPARTILHAMENTO PÚBLICO DO ESCOPO (link sem login)
--    Cada obra pode ter um token de compartilhamento. Quem tiver
--    o link (?share=TOKEN) consegue ver o Escopo em modo leitura,
--    sem precisar de conta. Gerar um novo token invalida o antigo.
-- ------------------------------------------------------------
alter table public.projects add column if not exists share_token text unique;

create index if not exists projects_share_token_idx
  on public.projects (share_token) where share_token is not null;

-- Função isolada: só devolve os campos necessários para a tela pública,
-- e só quando o token bate exatamente. Não abre a tabela para o público
-- (RLS de projects/profiles continua bloqueando leitura direta).
create or replace function public.get_shared_project(p_token text)
returns table (
  name text, type text, client text, address text,
  start_date date, status text, phases jsonb,
  company text, cnpj text, phone text, contact_email text,
  company_address text, logo text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.name, p.type, p.client, p.address, p.start_date, p.status, p.phases,
         pr.company, pr.cnpj, pr.phone, pr.contact_email, pr.address as company_address, pr.logo
  from public.projects p
  join public.profiles pr on pr.id = p.user_id
  where p.share_token = p_token
  limit 1;
$$;

grant execute on function public.get_shared_project(text) to anon;


-- ============================================================
--  FIM — se rodou sem erro, o banco está pronto.
-- ============================================================
