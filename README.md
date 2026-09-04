# Arq-Plano — Gestão de Projetos

Sistema de gestão de obras para escritórios de arquitetura: cadastro de obras,
cronograma, orçamento, acompanhamento de medição e pagamentos, e geração de
relatórios em PDF e Excel.

**Site publicado:** https://ornate-fox-ea12bd.netlify.app

---

## Estrutura das pastas

```
PUBLICAR/          O que vai para o ar
  index.html         Aplicação inteira (HTML + CSS + JS num arquivo só)
  robots.txt         Bloqueia indexação por buscadores

docs/              Documentação e materiais de apoio
  supabase-schema.sql  Script do banco de dados
  LOGO-ARQ-PLANO.png   Arte original do logo
  COMO-USAR.txt        Instruções da versão antiga (offline)

legacy/            Versão anterior, apenas para consulta
  gestor-obras.html    Versão offline, guardava dados só no navegador

netlify.toml       Configuração de publicação
```

**Para editar o sistema, mexa em `PUBLICAR/index.html`.** É o único arquivo da aplicação.

---

## Como publicar

O Netlify está conectado a este repositório. Todo `git push` para a branch
`main` publica automaticamente em ~30 segundos, no mesmo endereço.

```bash
git add .
git commit -m "descrição da mudança"
git push
```

Para acompanhar a publicação:
https://app.netlify.com/projects/ornate-fox-ea12bd/deploys

---

## Como testar antes de publicar

Dê duplo clique em `PUBLICAR/index.html`. Ele abre no navegador e usa o
mesmo banco de dados do site publicado, então o comportamento é idêntico.

---

## Infraestrutura

| Serviço | Função | Painel |
|---|---|---|
| **Netlify** | Hospedagem do site | [Painel](https://app.netlify.com/projects/ornate-fox-ea12bd) |
| **Supabase** | Login e banco de dados | [Painel](https://supabase.com/dashboard/project/oemsumsaymhtsluttyte) |

### Contas de acesso

O cadastro público está **desativado** (`ALLOW_SIGNUP = false` no início do
`index.html`). Novas contas são criadas manualmente:

**Supabase → Authentication → Users → Add user → Create new user**
(marque a caixa *Auto Confirm User*)

O administrador é `arqrafaelmp@gmail.com` — só ele vê o painel de usuários
dentro do sistema.

### Segurança dos dados

As regras de acesso (Row Level Security) ficam no banco, não no navegador.
Cada usuário só enxerga as próprias obras, mesmo que alguém altere o código
do site no navegador dele.

---

## Chaves e senhas

A chave que aparece no `index.html` (`sb_publishable_...`) é **pública por
design** — ela só funciona dentro das regras de segurança do banco.

**Nunca coloque no repositório:** a chave `sb_secret_...` do Supabase nem a
senha do banco de dados. Elas dão acesso administrativo total.
