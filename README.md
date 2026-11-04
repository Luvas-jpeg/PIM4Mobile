# PIM4Mobile — MediShop Aluno

Aplicativo Flutter para **Android**, destinado ao aluno da plataforma de cursos.
Reutiliza a conta e a API do site. O escopo desta primeira versão foi definido como
login, matrículas, informações das turmas, pedidos e perfil; **as compras são feitas no site**.

## Estado da validação — 17/10/2026

- Análise estática: sem problemas.
- Suíte normal: 20 testes aprovados e teste da API real opcional pulado.
- Teste do cliente com a API real: execução aprovada em 12/10/2026.
- APK debug gerado e assinatura v2 verificada; cache Kotlin entre C: e D: ajustado.
- Não houve teste em aparelho Android físico nesta etapa.

O projeto desativa compilação incremental Kotlin em android/gradle.properties
para evitar o erro de cache com dependências no C: e projeto no D:.
Referência: [documentação Kotlin](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).

## Prévia do aplicativo no navegador

Abra **http://localhost:4300** enquanto o servidor de prévia estiver em execução.
As telas são o próprio Flutter compilado para web, com uma moldura de celular;
não é um emulador Android. Use a mesma conta de aluno do site para consultar
matrículas, detalhes, pedidos e perfil. Compras continuam no site.

Para iniciar novamente, deixe a API local na porta 5278 e execute:

~~~powershell
cd D:\Projetos\PIM4Mobile
.\scripts\Preview-Mobile.ps1
~~~

Requer Flutter e Node.js. O script compila o app e mantém o servidor no terminal;
Ctrl+C encerra a prévia. O seletor muda o tamanho da tela e Girar alterna a orientação.

O servidor escuta somente no computador local. As chamadas /api são encaminhadas
para http://localhost:5278, sem alterar CORS da API. A compilação usa profile
para permitir HTTP local; a exigência de HTTPS no build release permanece.
A prévia permite avaliar telas, navegação e API; o comportamento Android ainda
precisa ser validado em aparelho ou emulador Android.

Para outras portas, informe -Port, -ApiBaseUrl e -WebBaseUrl. O script
recompila a prévia com as URLs escolhidas a cada inicialização.


## Participação e lembretes de turma

Site e app mostram quanto falta para o início e permitem confirmar participação
nos sete dias anteriores à turma. A confirmação é salva na API e aparece no admin.
Não confirmar não altera matrícula ou vaga.

O Android agenda notificações locais personalizadas, sem Firebase. Ative no perfil.
Datas e cancelamentos são atualizados quando o app sincroniza com a API. Há botão
para testar uma notificação usando uma turma futura. O agendador foi testado com
dispositivo substituto; a entrega visual no Android ainda precisa ser validada.

Configuração e limites:
[Notificações e participação](../PIM4API/docs/NOTIFICACOES-E-PARTICIPACAO.md).

## Funcionalidades implementadas

- Login com email/senha da conta do site.
- Sessão persistida com flutter_secure_storage, sem guardar a senha.
- Renovação de token após 401; chamadas simultâneas compartilham uma renovação.
- Saída da conta e limpeza local mesmo quando o servidor de logout não responde.
- Lista de matrículas, totais por situação, busca por curso/local/instrutor e filtro de status.
- Detalhes acessados pelo ID da matrícula: curso, data, local, instrutor e situação da turma.
- Lista de pedidos e detalhes com pagamento, valores, itens e turma.
- Edição de perfil, contato e endereço.
- Links externos para catálogo, cadastro, conta e pedido no site.
- Carregamento, mensagens de erro, tentar novamente e atualização puxando a lista.

Não há checkout nativo, modo offline, editor administrativo ou
player EAD nativo nesta primeira versão. Caso existam matrículas EAD, o conteúdo
pode ser aberto no site. As autorizações e a liberação após pagamento continuam
sendo responsabilidade da API.

## Projetos relacionados

| Pasta | Papel |
| --- | --- |
| PIM4Mobile | Este aplicativo Flutter do aluno |
| [PIM4API](../PIM4API/README.md) | Autenticação, regras, banco e endpoints |
| [PIM4Front](../PIM4Front/README.md) | Site, compra e administração web |
| [PIM4Desktop](../PIM4Desktop/README.md) | Administrativo Windows |

A pasta local deste projeto é `D:\Projetos\PIM4Mobile`.
O histórico geral está em [FLUXO-DE-DESENVOLVIMENTO.md](../PIM4API/FLUXO-DE-DESENVOLVIMENTO.md).

## Tecnologias e requisitos

- Flutter 3.47.7 / Dart 3.13.5, versões usadas na criação.
- Material 3 com localização pt-BR.
- HTTP: pacote http.
- Tokens: flutter_secure_storage.
- Navegador externo: url_launcher.
- Formatação: intl.
- Testes: flutter_test e MockClient.
- SDK Android e Java para compilar; aparelho Android ou emulador para executar.

Nesta máquina, o Flutter está em:

```text
C:\Users\Usuario\AppData\Local\Programs\Flutter
```

Se ainda não estiver no PATH, no PowerShell atual:

```powershell
$env:Path += ";$env:LOCALAPPDATA\Programs\Flutter\bin"
flutter --version
flutter doctor -v
```

A configuração do projeto Android usa os níveis de SDK definidos pelo Flutter.
Um APK de debug serve para testes; publicação na loja requer configuração de
produção e assinatura própria.

## Configuração dos servidores

As URLs são recebidas em tempo de compilação:

| Chave | Padrão de desenvolvimento |
| --- | --- |
| API_BASE_URL | http://10.0.2.2:5278/ |
| WEB_BASE_URL | http://10.0.2.2:4200/ |

Informe a **raiz** da API, sem acrescentar `/api`. O cliente compõe esse prefixo.
Não coloque tokens, senhas do banco ou segredos de pagamento em dart-define.

- Emulador Android padrão: `10.0.2.2` acessa o computador host.
- Celular na mesma rede: use o IPv4 local do computador e as portas corretas.
- Celular por USB com adb reverse: use `127.0.0.1` e configure os redirecionamentos.
- Produção: use URLs HTTPS reais. O app recusa configuração release com HTTP
  ou os endereços de loopback/emulador conhecidos.

O manifest permite HTTP somente em debug. Links para o site abrem no navegador:
a sessão do aplicativo não é copiada para ele; pode ser necessário entrar no site.

## Executar

Na pasta PIM4API, configure o ambiente conforme seu README e inicie os serviços:

```powershell
cd D:\Projetos\PIM4API
docker compose up -d
```

No mobile:

```powershell
cd D:\Projetos\PIM4Mobile
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5278/ --dart-define=WEB_BASE_URL=http://10.0.2.2:4200/
```

Para um aparelho específico, acrescente `-d ID_DO_APARELHO`.

### Celular na mesma rede

Descubra o IPv4 do computador. Exemplo ilustrativo:

```powershell
flutter run -d ID_DO_APARELHO --dart-define=API_BASE_URL=http://192.168.1.10:5278/ --dart-define=WEB_BASE_URL=http://192.168.1.10:4200/
```

PC e celular precisam se alcançar na rede. Confira a resposta da API e o acesso
ao site pelo navegador do aparelho; regras do firewall ou isolamento do Wi-Fi
podem impedir a conexão.

### Celular conectado por USB

Ative depuração USB e autorize o computador no aparelho. Com adb no PATH:

```powershell
adb devices
adb reverse tcp:5278 tcp:5278
adb reverse tcp:4200 tcp:4200
flutter run -d ID_DO_APARELHO --dart-define=API_BASE_URL=http://127.0.0.1:5278/ --dart-define=WEB_BASE_URL=http://127.0.0.1:4200/
```

O adb instalado nesta máquina fica em
`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
Os redirecionamentos podem precisar ser refeitos após desconectar o celular.

## Gerar APK de teste

Com Android SDK e Java configurados:

```powershell
.\scripts\Build-Android.ps1
```

Para gerar um APK que aponte ao computador na rede local:

```powershell
.\scripts\Build-Android.ps1 -ApiBaseUrl http://192.168.1.10:5278/ -WebBaseUrl http://192.168.1.10:4200/
```

Saída:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

A configuração padrão é para emulador. O APK de teste para celular precisa ser
compilado com URLs acessíveis ao aparelho, conforme as opções acima.
Trocar a URL exige recompilar/reinstalar.

O template Android ainda usa assinatura de debug para release. Antes de distribuir
em produção, definir applicationId definitivo, ícone/nome final, keystore de
release, política de privacidade e URLs HTTPS. Não distribuir um build de debug
como versão de loja.

### APK gerado nesta etapa

Em 17/10/2026 foi gerado build/app/outputs/flutter-apk/app-debug.apk, versão
1.0.0+1, aproximadamente 154 MB, com ARM64, ARMv7 e x86_64. Android mínimo: 7/API 24.
A assinatura de debug foi verificada; não é uma versão de produção.

Essa compilação aponta para API http://192.168.100.2:5278/ e site
http://192.168.100.2:4200/. Computador e celular precisam se alcançar na mesma rede.
Para conferir a conectividade antes do login, abra no navegador do celular:

- http://192.168.100.2:5278/health
- http://192.168.100.2:4200/

Copie o APK para o aparelho e abra o arquivo para instalar. Autorize a instalação
desse arquivo se o Android solicitar. Por USB, outra opção é:

~~~powershell
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
~~~

Se o IPv4 do computador mudar, gere outro APK com os endereços corretos.
Não há aparelho conectado para validar instalação, Keystore nativo e navegação
real nesta etapa; essa verificação permanece pendente.

## Endpoints usados

| Método | Rota | Uso |
| --- | --- | --- |
| POST | /api/Auth/login | Login |
| POST | /api/Auth/refresh | Renovação |
| POST | /api/Auth/revoke | Encerrar sessão |
| PUT | /api/Auth/perfil | Salvar perfil |
| GET | /api/me/courses | Matrículas do aluno |
| GET | /api/me/enrollments/{id} | Detalhes pelo ID da matrícula |
| GET | /api/Orders/my | Pedidos próprios |
| GET | /api/Orders/{id} | Detalhes do pedido |

O aplicativo não acessa Products, PostgreSQL ou endpoints administrativos.
Pedido pendente não libera matrícula; essa regra vem da API.

## Testes

```powershell
flutter analyze
flutter test
```

Os testes cobrem contrato de login, armazenamento sem senha, refresh concorrente,
sessão expirada, logout concorrente com refresh, atualização de perfil e
navegação para a matrícula correta. Testes de interface usam respostas controladas;
não comprovam funcionamento do Keystore nem execução em aparelho físico.

Há um teste opcional contra a API local real:

```powershell
flutter test test/real_api_smoke_test.dart --dart-define=LIVE_API=true
```

Ele cria uma conta fictícia com email `flutter-teste-...@example.com`, autentica,
consulta matrículas/pedidos, altera o perfil e encerra a sessão. A conta fica no banco
para inspeção. Não faz compras ou pagamentos e não aceita servidor externo.
Na suíte normal esse cenário é pulado.

Para outra porta local, acrescente
`--dart-define=LIVE_API_URL=http://localhost:PORTA/`.

## Estrutura

```text
lib/
├── main.dart                  # Inicialização e validação da configuração
├── student_app.dart           # Tema, localização e estado da sessão
├── core/
│   ├── app_config.dart        # URLs e validação de release
│   ├── api_client.dart        # HTTP, autenticação, refresh e endpoints
│   ├── session_store.dart     # Armazenamento seguro
│   └── formatters.dart        # Valores, datas e situações
├── features/
│   ├── login_page.dart
│   ├── student_home.dart      # Cursos e pedidos
│   ├── detail_pages.dart      # Matrícula e pedido
│   └── profile_page.dart
└── ui/shared.dart             # Estados, botões e componentes comuns
android/                       # Projeto Android
test/                          # Testes da sessão, interface e API real opcional
scripts/Build-Android.ps1       # Build debug configurável
```

## Pendências de entrega

- Validar instalação e navegação em aparelho Android real.
- Definir endereço público da API e site.
- Preparar identidade visual final e assinatura de distribuição.
- Validar storage nativo, links e comportamento ao suspender/retomar o app.
- Definir distribuição por APK ou Play Store.
- Notificações de lembrete antes do curso: melhoria futura.



## Revisão completa — 17/10/2026

[Relatório dos quatro projetos](../PIM4API/docs/AUDITORIA-COMPLETA-2026-10-17.md): funcionalidades, tecnologias, banco, testes, riscos encontrados e etapas para publicação.

## Correções — 24/10/2026

[Registro das correções](../PIM4API/docs/CORRECOES-AUDITORIA-2026-10-24.md): vagas/transações, uma vaga por curso, sessão, dependências, backup e configuração de publicação. Pagamento externo permanece pendente.
