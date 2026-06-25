# MatchPoint UFBA

**Documento acadêmico (SAD):** `Especificacoes_matchpoint_UFBA.pdf`

---

## Pré-requisitos

| Ferramenta | Versão mínima | Download |
|---|---|---|
| Flutter SDK | 3.11.4 | https://docs.flutter.dev/get-started/install |
| Dart SDK | 3.11.4 | (incluído no Flutter) |
| JDK | 17 | https://www.oracle.com/java/technologies/downloads/#java17 |
| Android Studio | Qualquer recente | https://developer.android.com/studio |
| Node.js | 18+ | https://nodejs.org |
| Xcode (apenas macOS) | 15+ | App Store |

Verifique a instalação do Flutter:
```bash
flutter doctor
```
Todos os itens relevantes devem estar marcados com ✓.

---

## 1. Clonar e instalar dependências

```bash
git clone https://github.com/BrunoBehrmann/SAD-Match-Point-UFBA
cd matchpoint
flutter pub get
```

---

## 2. Configurar Firebase (Google Sign-In no Android)

O Google Sign-In exige que a **SHA-1 do seu keystore de debug** esteja registrada no Firebase. Cada desenvolvedor precisa fazer isso uma vez.

### 2.1 Obter sua SHA-1

**Windows (PowerShell):**
```powershell
keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**macOS / Linux:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copie a linha `SHA1: XX:XX:XX:...` da saída.

> **Problema com formato do keystore?** Se aparecer "Invalid keystore format", rode via Gradle:
> ```bash
> cd android && ./gradlew signingReport   # macOS/Linux
> ```
> ```powershell
> # Windows (PowerShell) — defina JAVA_HOME para o JDK 17 antes
> $env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
> cd android; .\gradlew signingReport
> ```

### 2.2 Registrar no Firebase Console

1. Acesse o Firebase Console → projeto **matchpoint-ufba**
2. Engrenagem ⚙️ → **Configurações do projeto** → aba **Seus apps**
3. Clique no app Android (`com.ufba.matchpoint`) → **Adicionar impressão digital**
4. Cole sua SHA-1 e salve

### 2.3 Atualizar google-services.json

Após salvar a SHA-1:

1. Na mesma tela, clique em **Baixar google-services.json**
2. Substitua o arquivo em `android/app/google-services.json`
3. Faça commit do arquivo atualizado para o repositório

> O `google-services.json` precisa conter a SHA-1 de **todos** os desenvolvedores ativos. Quem adicionar uma SHA-1 nova é responsável por baixar e commitar o arquivo atualizado.

---

## 3. Configurar Firestore

### 3.1 Regras de segurança

No Firebase Console → **Firestore Database** → aba **Regras**, configure:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /atleticas/{id} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    match /eventos/{eventoId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if false;
    }
  }
}
```

### 3.2 Índice composto

A listagem de eventos requer um índice composto. Crie em **Firestore → Índices → Adicionar índice**:

| Coleção | Campo | Ordem |
|---|---|---|
| `eventos` | `status` | Crescente |
| `eventos` | `indiceViabilidade` | Decrescente |

> Alternativamente, ao rodar o app pela primeira vez, o Firestore exibe no terminal um link direto para criar o índice automaticamente. Copie e abra no navegador.

### 3.3 Popular a coleção de atléticas

A coleção `atleticas` precisa estar populada para o cadastro de usuários funcionar. Use o script de seed que já inclui todas as 30 atléticas da UFBA e o documento sentinel `sem-atletica`:

**1. Gerar a chave de serviço do Firebase:**
1. Firebase Console → ⚙️ Configurações do projeto → aba **Contas de serviço**
2. Clique em **Gerar nova chave privada** e salve o arquivo como `serviceAccountKey.json` dentro da pasta `scripts/`

> `serviceAccountKey.json` está no `.gitignore` — nunca commite esse arquivo.

**2. Rodar o script:**
```bash
cd scripts
npm install
node seed_atleticas.js
```

Saída esperada: `✅ 31 atléticas inseridas (30 reais + sentinel).`

---

## 4. Rodar o app

```bash
flutter run
```

Para escolher o dispositivo:
```bash
flutter devices        # lista dispositivos disponíveis
flutter run -d <id>    # roda no dispositivo escolhido
```

---

## 5. Testes

```bash
flutter test                        # todos os testes
flutter test test/widget_test.dart  # teste específico
```

---

## Problemas comuns

**`ApiException: 10` no login Google**
→ Sua SHA-1 não está registrada no Firebase. Siga o passo 2.

**Spinner infinito ou "Nenhuma atlética cadastrada"**
→ Nenhum documento na coleção `atleticas` no Firestore. Siga o passo 3.3.

**Erro de índice na tela de eventos**
→ O índice composto não foi criado. Siga o passo 3.2.

**`BUILD FAILED: requires JVM runtime version 11`**
→ O Gradle está usando JDK 8. Defina o JDK 17 antes de rodar o Gradle:
```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
```
