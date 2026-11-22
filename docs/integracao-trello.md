# 📋 Integração Trello — Guia e Padrão para Agentes

> **Regra Obrigatória para Agentes**: Sempre que qualquer agente for interagir com o Trello ou criar cards para o projeto **Monetis**, deve seguir rigorosamente as regras de segurança, codificação de caracteres e padrão de formatação definidos neste documento.

---

## 1. 🔒 Segurança e Credenciais (Regra Inegociável)

* As credenciais do Trello ficam armazenadas no arquivo `.env` na raiz do repositório (arquivo já protegido no [.gitignore](file:///C:/dev/monetis-backend/.gitignore#L7)):
  ```env
  TRELLO_KEY=sua_key_aqui
  TRELLO_TOKEN=seu_token_aqui
  ```
* **Proteção de Segredos**:
  * **NUNCA** exiba, imprima (`Write-Host`, `echo`), faça log ou repita a `TRELLO_KEY` ou o `TRELLO_TOKEN` no chat, transcrições ou saída do terminal.
  * O agente deve ler o `.env` estritamente em memória durante a execução do script.
  * Se o arquivo `.env` não existir ou faltar alguma variável, avise o usuário sem tentar inferir ou solicitar que ele digite as chaves no chat.

---

## 2. 📌 Mapeamento do Quadro Monetis

* **Nome do Quadro:** `Monetis`
* **Board ID:** `69c43cb8ed9266858bde2654`

### Listas (Colunas) Disponíveis:

| Lista | ID da Lista | Finalidade / Quando Usar |
| :--- | :--- | :--- |
| **Backlog** | `69c43cb8ed9266858bde264d` | Fases futuras (Fase 1 em diante) ou tarefas planejadas |
| **A Fazer** | `69c43cb8ed9266858bde264f` | Tarefas prontas para execução imediata (ex.: Fase 0 / Hotfixes) |
| **Em andamento** | `69c43cb8ed9266858bde2650` | Tarefa que está sendo desenvolvida no momento |
| **Revisao de código** | `69c43cb8ed9266858bde2651` | Pull Requests ou código aguardando revisão do instrutor |
| **Fase de teste** | `69c43cb8ed9266858bde2652` | Código implementado em processo de testes unitários/integração |
| **Concluído 🚀** | `69c43cb8ed9266858bde2653` | Cards finalizados, testados e com build verde |

---

## 3. ⚠️ Tratamento Obrigatório de Encoding UTF-8 (Prevenção de Mojibake)

### O Problema
No Windows PowerShell 5.1, comandos e arquivos `.ps1` assumem por padrão a codificação ANSI/Windows-1252. Se você tentar enviar requisições com strings acentuadas ou emojis diretamente pelo PowerShell, os dados chegarão corrompidos no Trello (ex.: `ðŸ§ª [Teste] ConexÃ£o`).

### A Regra Obrigatória
1. **Ao ler arquivos Markdown ou de configuração:**
   Use sempre `[System.IO.File]::ReadAllLines($caminho, [System.Text.Encoding]::UTF8)`.
2. **Ao montar o payload HTTP para a API do Trello:**
   * Converta o objeto do card para JSON com `ConvertTo-Json -Compress`.
   * Obtenha os bytes UTF-8 explicitamente:
     ```powershell
     $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)
     ```
   * Envie a requisição com o charset explícito:
     ```powershell
     Invoke-RestMethod -Uri "https://api.trello.com/1/cards?key=$trelloKey&token=$trelloToken" `
         -Method Post `
         -ContentType "application/json; charset=utf-8" `
         -Body $utf8Bytes
     ```

---

## 4. 📝 Padrão Estrutural de um Card

Cada card criado deve seguir o padrão de qualidade e clareza do Monetis:

### 4.1 Formato do Título
`[Fase X] <Prefixo/Emoji> <Nome Objetivo da Tarefa>`

Exemplos:
* `[Fase 0] 🔴 Hotfix: Desbloqueio da Compilação em AuthController.cs`
* `[Fase 0] 🛡️ Segurança: OWASP IDOR em UserResourceGuard`
* `[Fase 1] 🧪 Testes: Bateria de Testes Unitários da Entidade Account`
* `[Fase 2] 💰 Domínio: Value Object Money com Arredondamento Bancário`

### 4.2 Formato da Descrição (Markdown)
```markdown
### 📍 Local
- `src/Monetis.API/Controllers/AuthController.cs`

### 🔎 Diagnóstico & Contexto
Explicação clara do problema, do risco arquitetural ou do objetivo da funcionalidade.

### 💡 Solução Proposta
Passos práticos de implementação recomendados pela arquitetura do projeto.

### 📚 Por Quê
Justificativa técnica (Clean Architecture, DDD, OWASP, RFCs).

### 🔗 Referências
- Links para documentação oficial relevante (Microsoft Learn, OWASP API Security, RFC 9457).
```

### 4.3 Checklists de Tarefas
Todo card deve conter um checklist chamado **`Critérios de Aceite`** ou **`Tarefas`** criado via API do Trello:
1. Criar checklist:
   `POST https://api.trello.com/1/cards/{cardId}/checklists?name=Critérios de Aceite&key=...&token=...`
2. Adicionar itens (`checkItems`):
   `POST https://api.trello.com/1/checklists/{checklistId}/checkItems?name=Subtarefa&key=...&token=...`

---

## 5. 🛠️ Script Utilitário: `scripts/trello-sync.ps1`

Para automatizar a criação em lote a partir do [PLANO-DE-EVOLUCAO.md](file:///C:/dev/monetis-backend/docs/PLANO-DE-EVOLUCAO.md) sem erros manuais, utilize o script em [scripts/trello-sync.ps1](file:///C:/dev/monetis-backend/scripts/trello-sync.ps1).
