# 💰 Monetis — API

API REST para gerenciamento de finanças pessoais, desenvolvida em ASP.NET Core e SQL Server. O repositório também funciona como laboratório de aprendizado e evolução de arquitetura de software.

> 🚧 Em desenvolvimento. A presença de um endpoint ou componente não significa que todos os cenários estejam cobertos por testes ou prontos para produção.

## Funcionalidades atuais

- Cadastro e autenticação de usuários com JWT.
- Cadastro, consulta, edição e exclusão de contas, cartões e categorias.
- Categorias compartilhadas do sistema e categorias do usuário.
- Registro, consulta, edição e pagamento de despesas; criação de parcelas no cartão de crédito.
- Registro e gerenciamento de receitas.
- Cadastro e gerenciamento de assinaturas, com geração da primeira despesa na criação e cancelamento lógico.
- Transferências entre contas, com edição de valor e cancelamento conforme as regras de domínio.
- Endpoint autenticado para marcar despesas vencidas e um serviço em segundo plano registrado para esse processamento.

Dashboard e relatório mensal ainda não possuem controllers neste repositório. A geração periódica das próximas despesas de assinaturas também não está conectada a um agendador.

## Stack e configuração

| Componente | Configuração no repositório |
|---|---|
| Framework | .NET / ASP.NET Core 10 (`net10.0`) |
| SDK | `10.0.111`, com `rollForward: latestFeature` em `global.json` |
| C# | `LangVersion: latest`, nullable habilitado |
| Persistência | EF Core 10.0.13 e SQL Server |
| Autenticação | JWT Bearer 10.0.7 |
| Validação | FluentValidation 12.2.0 |
| Documentação HTTP | Swagger / Swashbuckle e OpenAPI, em Development |
| Testes | xUnit, FluentAssertions e coverlet |
| Análise estática | Analisadores .NET e SonarAnalyzer; warnings tratados como erros |

As versões de pacotes são centralizadas em [Directory.Packages.props](Directory.Packages.props), e as propriedades comuns de build em [Directory.Build.props](Directory.Build.props).

## Arquitetura

A solução está organizada em quatro camadas, seguindo a proposta de Clean Architecture:

```text
src/
  Monetis.Domain/          Entidades, enums e exceções de domínio
  Monetis.Application/     Serviços, DTOs, validadores e abstrações
  Monetis.Infrastructure/  EF Core, repositórios, Unit of Work e segurança
  Monetis.API/             Controllers, middlewares e serviço em segundo plano
tests/
  Monetis.Domain.Tests/    Testes unitários de domínio
```

- **Domain:** não declara referências a outros projetos nem pacotes específicos no seu `.csproj`; recebe os analisadores definidos globalmente.
- **Application:** referencia o Domain e define as interfaces de persistência, segurança e serviços em `Abstractions`.
- **Infrastructure:** implementa essas abstrações e registra persistência e autenticação na injeção de dependências.
- **API:** compõe os serviços e expõe os casos de uso por HTTP.

### Persistência e regras financeiras

Os repositórios compartilham operações em `BaseRepository<T>`. A classe `UnitOfWork` implementa `IUnitOfWork`: atribui o usuário às novas entidades com proprietário e chama `SaveChangesAsync` no `MonetisDataContext`.

Criação de transferência, pagamento de despesa e criação de assinatura persistem suas alterações por um `CommitAsync` ao final do caso de uso. Isso não constitui garantia de proteção contra atualizações concorrentes de saldo.

`Expense`, `Income` e `Transfer` herdam de `Transaction` e usam TPC (Table Per Concrete Type), com tabelas separadas. O valor de transação é mapeado como `decimal(18,2)`.

### Contexto do usuário

O contexto autenticado é resolvido a partir do JWT pelo `UserContextMiddleware`. Filtros globais no EF Core restringem as entidades com proprietário ao usuário resolvido; categorias também permitem os registros compartilhados cujo `UserId` é nulo. O `UserResourceGuard` oferece consultas para validar contas, cartões e categorias relacionados aos casos de uso.

Esses mecanismos não substituem a verificação de autorização em cada fluxo nem testes de integração de isolamento entre usuários.

### Processamento de despesas vencidas

O `OverDueExpenseProcessorService` cria um escopo de serviços e agenda a execução diária para 00:01 UTC. O processamento consulta despesas vencidas e atualiza seu estado.

**Escopo atual:** `ExpenseRepository.GetOverdueAsync` usa `IgnoreQueryFilters()` para consultar despesas pendentes vencidas de todos os usuários. Tanto o serviço em segundo plano quanto o endpoint manual chamam esse método; portanto, o processamento manual também tem alcance global, embora exija autenticação.

## Executar localmente

### Pré-requisitos

- SDK .NET 10 compatível com `global.json`.
- SQL Server acessível e um banco preparado com o esquema das migrations.
- Configuração local de conexão e JWT.

```bash
git clone https://github.com/ViniciusMoraisAraujo/monetis-backend.git
cd monetis-backend
dotnet restore
```

### Configuração da API

Forneça as opções por variáveis de ambiente ou por um provedor de configuração local apropriado. Não versione credenciais.

| Variável de ambiente | Finalidade |
|---|---|
| `ConnectionStrings__MonetisConnection` | Conexão com SQL Server |
| `Jwt__Key` | Chave secreta de assinatura, com no mínimo 32 caracteres conforme `JwtOptions` |
| `Jwt__Issuer` | Emissor esperado do token |
| `Jwt__Audience` | Público esperado do token |
| `Jwt__DurationInMinutes` | Duração; padrão 240 e faixa validada de 220 a 250 minutos |

A chave JWT é lida como texto UTF-8 pela implementação, sem decodificação Base64.

### Preparar o banco

A aplicação não aplica migrations automaticamente no `Program.cs`. Prepare apenas o banco local escolhido para desenvolvimento.

A factory de design time atual resolve `../Monetis.API` a partir do diretório de execução e carrega os arquivos JSON de configuração. Por isso, para o comando abaixo, configure localmente `ConnectionStrings:MonetisConnection` em `src/Monetis.API/appsettings.Development.json` e execute a partir de `src/Monetis.Infrastructure`. Essa factory não lê as variáveis de ambiente listadas acima.

Com a ferramenta `dotnet-ef` compatível com EF Core 10 instalada:

```bash
cd src/Monetis.Infrastructure
dotnet ef database update --startup-project ../Monetis.API
cd ../..
```

Esse comando altera o banco indicado na configuração; confira o destino antes de executá-lo.

### Iniciar a API

```bash
dotnet run --project src/Monetis.API --launch-profile https
```

No perfil `https`, a API usa `https://localhost:7260` e `http://localhost:5074`. Em Development:

- Swagger UI: `https://localhost:7260/swagger`.
- OpenAPI: `https://localhost:7260/openapi/v1.json`.

A política CORS atual permite a origem `http://localhost:4200`. O host registra o serviço de despesas vencidas ao iniciar.

## Endpoints

As rotas abaixo usam a grafia dos controllers. Para operações sobre um recurso existente, acrescente `/{id}` conforme indicado pelo Swagger.

| Método | Rota | Operação |
|---|---|---|
| POST | `/api/Auth/register` | Cadastro público de usuário |
| POST | `/api/Auth/login` | Login público; retorna `{ "token": "..." }` |
| GET, PUT, DELETE | `/api/Users/{id}` | Consultar, atualizar ou excluir usuário |
| GET | `/api/Users` | Listar usuários |
| GET, POST | `/api/Accounts`, `/api/Cards`, `/api/Categories` | Listar ou criar |
| GET, PUT, DELETE | `/api/Accounts/{id}`, `/api/Cards/{id}`, `/api/Categories/{id}` | Consultar, atualizar ou excluir |
| GET, POST | `/api/Expenses` | Listar ou criar despesas |
| GET, PUT | `/api/Expenses/{id}` | Consultar ou atualizar despesa |
| POST | `/api/Expenses/installments` | Criar despesas parceladas |
| POST | `/api/Expenses/{id}/pay` | Pagar despesa |
| POST | `/api/Expenses/process-overdue` | Processar despesas vencidas de todos os usuários |
| GET, POST | `/api/Incomes`, `/api/Subscriptions`, `/api/Transfers` | Listar ou criar |
| GET, PUT, DELETE | `/api/Incomes/{id}`, `/api/Subscriptions/{id}`, `/api/Transfers/{id}` | Consultar, atualizar ou excluir/cancelar |

As rotas de recursos exigem autenticação Bearer. Após o login, envie `Authorization: Bearer <token>`. Os contratos de entrada e saída estão em `src/Monetis.Application/DTOs` e na documentação gerada pela API.

## Verificação local

Na raiz do repositório:

```bash
dotnet build Monetis.slnx
dotnet test Monetis.slnx
```

A suíte presente na `main` inclui testes de `User` e `UserOwnedEntity`. Ela ainda não representa cobertura abrangente das operações financeiras. Não há projeto de testes de integração na solução atual.

## Evolução

- Ampliar testes de domínio e adicionar testes de integração de persistência e autorização.
- Validar concorrência nas operações de saldo.
- Completar a automação de recorrência das assinaturas e revisar a autorização do processamento global de despesas.
- Desenvolver dashboard e relatório mensal.

Consulte a [visão geral](docs/00-visao-geral.md) para contexto adicional e a [integração com Trello](docs/integracao-trello.md) para o fluxo de acompanhamento técnico. O comportamento descrito neste README foi conferido no código da `main`; documentos de planejamento podem representar objetivos ainda não implementados.
