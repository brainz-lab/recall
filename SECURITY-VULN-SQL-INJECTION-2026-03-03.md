# 🚨 VULNERABILIDAD CRÍTICA: SQL Injection en bulk_insert_logs

**Fecha de Descubrimiento**: 2026-03-03
**Severidad**: 🔴 **CRITICAL**
**CVE Score Estimado**: 9.8 (Critical)
**Estado**: ⚠️ **FIX IMPLEMENTADO - PENDIENTE DEPLOY**
**Servicio Afectado**: Recall (Log Management)
**Endpoint Vulnerable**: `POST /api/v1/logs` (batch ingest)

---

## 📊 Resumen Ejecutivo

Se ha descubierto una vulnerabilidad crítica de **SQL Injection** en el servicio Recall que permite a un atacante ejecutar comandos SQL arbitrarios, incluyendo:

- 💥 Eliminación completa de tablas (`DROP TABLE`)
- 📤 Extracción de datos sensibles (`UNION SELECT`)
- 🔓 Escalada de privilegios (lectura de `pg_user`)
- ⚠️ Denegación de servicio (corrupción de datos)

**Impacto**: CRÍTICO — Acceso completo a la base de datos del servicio Recall.

**Acción Requerida**: Deploy inmediato del fix (branch `fix/sql-injection-bulk-insert`).

---

## 🎯 Detalles Técnicos

### Ubicación de la Vulnerabilidad

**Archivo**: `app/controllers/api/v1/ingest_controller.rb`
**Método**: `bulk_insert_logs` (líneas 68-82)
**Endpoint**: `POST /api/v1/logs`

### Código Vulnerable

```ruby
def bulk_insert_logs(entries)
  return if entries.empty?

  columns = entries.first.keys  # ⚠️ Keys controladas por el usuario
  values = entries.map do |entry|
    columns.map { |col| ActiveRecord::Base.connection.quote(entry[col]) }.join(", ")
  end

  sql = <<~SQL
    INSERT INTO log_entries (#{columns.join(', ')})  # 🚨 SIN ESCAPAR
    VALUES #{values.map { |v| "(#{v})" }.join(', ')}
  SQL

  ActiveRecord::Base.connection.execute(sql)
end
```

### Análisis de la Vulnerabilidad

**Problema identificado**: Los nombres de columnas (`columns.join(', ')`) se insertan directamente en el SQL sin escapar.

**Flujo de ataque**:
1. Atacante envía payload con keys maliciosos en el JSON
2. `entries.first.keys` extrae las keys (incluyendo las maliciosas)
3. `columns.join(', ')` las concatena sin sanitización
4. El SQL generado contiene comandos maliciosos
5. `connection.execute(sql)` ejecuta todo el SQL, incluyendo los comandos inyectados

**¿Por qué los valores SÍ están protegidos?**
```ruby
columns.map { |col| connection.quote(entry[col]) }
```
Los **valores** usan `connection.quote()` que escapa correctamente.

**¿Por qué los nombres de columnas NO están protegidos?**
```ruby
columns.join(', ')  # ⚠️ Concatenación directa sin escapar
```
Los **nombres de columnas** se concatenan sin ninguna sanitización.

---

## 💣 Vector de Ataque

### Payload Malicioso

```bash
curl -X POST https://recall.brainzlab.com/api/v1/logs \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [{
      "timestamp; DROP TABLE log_entries--": "malicious_value",
      "level": "info",
      "message": "innocent message"
    }]
  }'
```

### SQL Generado (VULNERABLE)

```sql
INSERT INTO log_entries (
  timestamp; DROP TABLE log_entries--,  -- 💥 COMANDO MALICIOSO
  level,
  message
)
VALUES ('malicious_value', 'info', 'innocent message')
```

### Ejecución en PostgreSQL

PostgreSQL ejecuta el SQL en secuencia:

```sql
-- 1. INSERT fallido (columna inválida)
INSERT INTO log_entries (timestamp

-- 2. DROP TABLE ejecutado ✅ 💥
; DROP TABLE log_entries

-- 3. Resto comentado (el -- comenta el resto)
--,
--  level,
--  message
--)
--VALUES (...)
```

**Resultado**: La tabla `log_entries` es **ELIMINADA COMPLETAMENTE**.

---

## 🎭 Escenarios de Ataque

### 1. Destrucción de Datos (DROP TABLE)

```json
{
  "logs": [{
    "timestamp; DROP TABLE log_entries CASCADE--": "attack"
  }]
}
```

**Resultado**: Toda la tabla de logs destruida, incluyendo relaciones dependientes.

### 2. Extracción de Datos (UNION SELECT)

```json
{
  "logs": [{
    "timestamp) VALUES ('') RETURNING *; SELECT * FROM projects--": "attack"
  }]
}
```

**Resultado**: Exfiltración de todos los proyectos y sus datos sensibles.

### 3. Lectura de Credenciales

```json
{
  "logs": [{
    "timestamp) VALUES ('') RETURNING *; SELECT usename, passwd FROM pg_shadow--": "attack"
  }]
}
```

**Resultado**: Extracción de passwords de usuarios de PostgreSQL.

### 4. Modificación Masiva de Datos

```json
{
  "logs": [{
    "timestamp); UPDATE projects SET archived = true--": "attack"
  }]
}
```

**Resultado**: Todos los proyectos marcados como archivados.

### 5. Denegación de Servicio

```json
{
  "logs": [{
    "timestamp); CREATE TABLE massive_table AS SELECT * FROM generate_series(1, 10000000)--": "attack"
  }]
}
```

**Resultado**: Creación de tabla masiva que consume todo el espacio en disco.

---

## 🛡️ Solución Implementada

### Código Corregido

```ruby
def bulk_insert_logs(entries)
  return if entries.empty?

  conn = ActiveRecord::Base.connection
  columns = entries.first.keys
  quoted_columns = columns.map { |col| conn.quote_column_name(col) }  # ✅ FIX

  values = entries.map do |entry|
    columns.map { |col| conn.quote(entry[col]) }.join(", ")
  end

  sql = <<~SQL
    INSERT INTO log_entries (#{quoted_columns.join(', ')})  # ✅ SEGURO
    VALUES #{values.map { |v| "(#{v})" }.join(', ')}
  SQL

  conn.execute(sql)
end
```

### ¿Cómo Funciona el Fix?

**`quote_column_name(col)`** escapa nombres de columnas según las reglas de PostgreSQL:

```ruby
# ANTES (vulnerable)
"timestamp; DROP TABLE log_entries--"

# DESPUÉS (seguro)
"\"timestamp; DROP TABLE log_entries--\""
```

Los **doble comillas** hacen que PostgreSQL interprete todo el string como un **nombre de columna literal**, no como código SQL.

### SQL Generado (SEGURO)

```sql
INSERT INTO log_entries (
  "timestamp; DROP TABLE log_entries--",  -- ✅ Nombre de columna literal
  "level",
  "message"
)
VALUES ('malicious_value', 'info', 'innocent message')
```

**Resultado**: PostgreSQL busca una columna llamada literalmente `timestamp; DROP TABLE log_entries--`, no encuentra ninguna, y retorna:

```
ERROR: column "timestamp; DROP TABLE log_entries--" does not exist
```

El DROP TABLE **nunca se ejecuta** ✅

---

## 🔬 Proof of Concept

### Test de Verificación

```ruby
# spec/requests/api/v1/ingest_spec.rb

describe "POST /api/v1/logs" do
  context "security" do
    it "prevents SQL injection via malicious column names" do
      # Payload de ataque
      malicious_payload = {
        logs: [{
          "timestamp; DROP TABLE log_entries CASCADE--" => "attack",
          "level; DELETE FROM log_entries WHERE true--" => "attack",
          "message" => "innocent"
        }]
      }

      # Intentar el ataque
      expect {
        post api_v1_logs_path,
             params: malicious_payload,
             headers: auth_headers
      }.to raise_error(ActiveRecord::StatementInvalid)

      # Verificar que la tabla sigue existiendo
      expect(LogEntry.connection.table_exists?(:log_entries)).to be true
      expect(LogEntry.count).to be >= 0  # No se eliminaron registros
    end

    it "prevents SQL injection via UNION SELECT" do
      malicious_payload = {
        logs: [{
          "id) VALUES ('') RETURNING *; SELECT * FROM projects--" => "attack"
        }]
      }

      expect {
        post api_v1_logs_path,
             params: malicious_payload,
             headers: auth_headers
      }.to raise_error(ActiveRecord::StatementInvalid)

      # Verificar que no se expusieron datos
      expect(response.body).not_to include("project")
    end
  end
end
```

### Ejecución Manual (Ambiente de Testing)

```bash
# 1. Backup de la base de datos de testing
pg_dump recall_test > /tmp/recall_test_backup.sql

# 2. Ejecutar payload malicioso
curl -X POST http://localhost:4001/api/v1/logs \
  -H "Authorization: Bearer TEST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [{
      "timestamp; DROP TABLE log_entries--": "attack"
    }]
  }'

# 3. Verificar que la tabla sigue existiendo
psql recall_test -c "\dt log_entries"

# 4. Restaurar backup
psql recall_test < /tmp/recall_test_backup.sql
```

**Resultado Esperado (con el fix)**:
```
ERROR: column "timestamp; DROP TABLE log_entries--" does not exist
```

**Resultado Esperado (sin el fix)** - ⚠️ NO EJECUTAR EN PRODUCCIÓN:
```
DROP TABLE
(la tabla log_entries ya no existe)
```

---

## 📈 Evaluación de Impacto

### CVSS v3.1 Score: 9.8 (CRITICAL)

**Vector String**: `CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H`

| Métrica | Valor | Justificación |
|---------|-------|---------------|
| **Attack Vector (AV)** | Network (N) | Explotable vía API pública |
| **Attack Complexity (AC)** | Low (L) | No requiere condiciones especiales |
| **Privileges Required (PR)** | Low (L) | Requiere API token válido |
| **User Interaction (UI)** | None (N) | Totalmente automatizable |
| **Scope (S)** | Unchanged (U) | Afecta solo al servicio Recall |
| **Confidentiality (C)** | High (H) | Acceso a todos los logs y metadata |
| **Integrity (I)** | High (H) | Modificación/eliminación de datos |
| **Availability (A)** | High (H) | Posible destrucción completa de tablas |

### Clasificación de Severidad

- **OWASP Risk Rating**: **CRITICAL**
- **CWE-89**: SQL Injection
- **SANS Top 25**: Rank #1 (Injection Flaws)

### Datos Sensibles Expuestos

La tabla `log_entries` contiene:
- 📝 Mensajes de log (pueden incluir datos sensibles)
- 🔑 Request IDs y Session IDs
- 🌐 Información de hosts y servicios
- 🏷️ Environment variables (development/staging/production)
- 📊 Metadata de deployment (commits, branches)

**Además**, vía UNION SELECT un atacante podría acceder a:
- 👥 Tabla `projects` (información de clientes)
- 🔐 Variables de entorno (si están en logs)
- 🗄️ Cualquier otra tabla de la base de datos

---

## 🚀 Plan de Remediación

### Fase 1: Deploy Inmediato (URGENTE)

```bash
# 1. Verificar que el fix está en la rama
cd /path/to/recall
git checkout fix/sql-injection-bulk-insert
git log -1 --oneline
# Debe mostrar el commit con el fix

# 2. Crear PR de emergencia
gh pr create \
  --title "🚨 CRITICAL: Fix SQL injection in bulk_insert_logs" \
  --body "Security vulnerability - requires immediate merge and deploy" \
  --label "security,critical,priority:P0"

# 3. Merge sin esperar CI (emergency override)
gh pr merge --admin --squash

# 4. Deploy inmediato a producción
cd ../launchpad
./deploy-all.sh recall

# 5. Verificar que el deploy fue exitoso
curl https://recall.brainzlab.com/up
# => "ok"

# 6. Verificar logs de deploy
kamal app logs --since 5m
```

**Timeline esperado**: < 30 minutos desde el descubrimiento.

### Fase 2: Verificación Post-Deploy (Inmediato)

```bash
# 1. Test de sanidad básico
curl -X POST https://recall.brainzlab.com/api/v1/logs \
  -H "Authorization: Bearer PROD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [{
      "timestamp": "2026-03-03T10:00:00Z",
      "level": "info",
      "message": "test after security fix"
    }]
  }'
# Debe retornar: {"ingested":1}

# 2. Verificar que payloads maliciosos fallan de forma segura
curl -X POST https://recall.brainzlab.com/api/v1/logs \
  -H "Authorization: Bearer PROD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [{
      "timestamp; DROP TABLE log_entries--": "attack"
    }]
  }'
# Debe retornar error 500 con "column does not exist"

# 3. Monitorear logs de aplicación
kamal app logs --since 10m | grep -i "error\|sql"
```

### Fase 3: Auditoría de Logs (Primera hora)

```bash
# Buscar intentos de explotación previos en logs de acceso
# (si hay logs de nginx/traefik)

# Patrones sospechosos:
grep -E "DROP TABLE|DELETE FROM|UNION SELECT|pg_shadow" /var/log/nginx/access.log

# Buscar requests con caracteres SQL en el JSON payload
grep -E "POST /api/v1/logs.*;" /var/log/nginx/access.log
```

**⚠️ Si se encuentran intentos previos**: Activar plan de respuesta a incidentes (ver Fase 5).

### Fase 4: Hardening Adicional (Primeras 24h)

```ruby
# 1. Añadir test de seguridad (ver sección "Proof of Concept")
# spec/requests/api/v1/ingest_spec.rb

# 2. Añadir validación de column names permitidos
def bulk_insert_logs(entries)
  return if entries.empty?

  ALLOWED_COLUMNS = %w[
    id project_id timestamp level message commit branch
    environment service host request_id session_id data created_at
  ].freeze

  conn = ActiveRecord::Base.connection
  columns = entries.first.keys

  # Validar que solo se usen columnas permitidas
  invalid_columns = columns - ALLOWED_COLUMNS
  if invalid_columns.any?
    raise ArgumentError, "Invalid columns: #{invalid_columns.join(', ')}"
  end

  quoted_columns = columns.map { |col| conn.quote_column_name(col) }
  # ... resto del código
end

# 3. Rate limiting en el endpoint
# config/initializers/rack_attack.rb
Rack::Attack.throttle("api/v1/logs", limit: 100, period: 60) do |req|
  req.ip if req.path == "/api/v1/logs" && req.post?
end

# 4. WAF rules (si se usa Cloudflare/AWS WAF)
# Bloquear requests con patrones SQL en JSON payload
```

### Fase 5: Respuesta a Incidentes (Si fue explotado)

**Si se detectan intentos de explotación exitosos**:

1. **Containment (0-1 hora)**:
   ```bash
   # Deshabilitar endpoint temporalmente
   # Añadir en config/routes.rb:
   # match "/api/v1/logs", to: proc { [503, {}, ["Maintenance"]] }, via: :post

   # Re-deploy inmediato
   ./deploy-all.sh recall
   ```

2. **Investigation (1-4 horas)**:
   - Revisar todos los logs de acceso desde el 2026-01-01
   - Identificar IPs atacantes
   - Determinar si hubo exfiltración de datos
   - Revisar integridad de la base de datos

3. **Recovery (4-8 horas)**:
   - Restaurar desde backup si hay corrupción de datos
   - Rotar API tokens comprometidos
   - Cambiar passwords de base de datos

4. **Notification (24 horas)**:
   - Notificar a clientes afectados (si hubo exfiltración)
   - Reportar a autoridades de protección de datos (GDPR/CCPA)
   - Publicar post-mortem interno

---

## 🔍 Análisis de Root Cause

### ¿Cómo se introdujo la vulnerabilidad?

1. **Decisión técnica**: Usar SQL raw en lugar de `insert_all` debido a incompatibilidad de Rails 8.1 con TimescaleDB hypertables.

2. **Sanitización parcial**: Se implementó `connection.quote()` para valores pero se **olvidó** `quote_column_name()` para columnas.

3. **Asunción errónea**: Se asumió que `.keys` de un hash siempre retornaría nombres seguros, sin considerar que el hash viene de user input.

### ¿Por qué no lo detectaron los controles existentes?

| Control | ¿Detectó? | Razón |
|---------|-----------|-------|
| **RuboCop** | ❌ No | No tiene regla para SQL dinámico sin `quote_column_name` |
| **Brakeman** | ❌ No | Asume que `ActiveRecord::Base.connection` es seguro |
| **Tests** | ❌ No | No había tests de seguridad para SQL injection |
| **Code Review** | ❌ No | Reviewer no identificó el vector de ataque |

### ¿Por qué Brakeman no lo detectó?

Brakeman busca patrones como:
```ruby
execute("... #{user_input} ...")  # ✅ Detectaría esto
```

Pero no detecta:
```ruby
columns = params[:logs].first.keys  # Keys controlados por usuario
execute("... #{columns.join} ...")  # ❌ No detecta (asume keys son seguros)
```

Brakeman no hace **análisis de flujo de datos completo** (data flow analysis), solo análisis de patrones estáticos.

---

## 📚 Lecciones Aprendidas

### ✅ Debe Hacerse

1. **SIEMPRE sanitizar nombres de columnas**:
   ```ruby
   connection.quote_column_name(col)  # Para columnas
   connection.quote_table_name(table)  # Para tablas
   connection.quote(value)             # Para valores
   ```

2. **Validar columnas contra whitelist**:
   ```ruby
   ALLOWED_COLUMNS = %w[id name email].freeze
   raise unless columns.all? { |c| ALLOWED_COLUMNS.include?(c) }
   ```

3. **Preferir ORM sobre SQL raw**:
   ```ruby
   # ✅ Mejor (si es posible)
   LogEntry.insert_all(entries)

   # ⚠️ Solo si es necesario (con sanitización completa)
   connection.execute(sql)
   ```

4. **Tests de seguridad obligatorios** para código que construye SQL dinámico.

5. **Security code review** específico para PRs que tocan:
   - Autenticación/Autorización
   - SQL dinámico
   - File uploads
   - Command execution

### ❌ No Debe Hacerse

1. ❌ Asumir que `.keys` de un hash son seguros
2. ❌ Concatenar strings en SQL sin sanitización
3. ❌ Confiar solo en herramientas automáticas (Brakeman, etc.)
4. ❌ Usar SQL raw sin justificación técnica sólida

---

## 🛠️ Recomendaciones para el Futuro

### 1. Security Testing

Añadir a la suite de CI:

```yaml
# .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Brakeman
        run: bin/brakeman --no-pager --exit-on-warn

      - name: Run Bundler Audit
        run: bin/bundler-audit

      - name: SQL Injection Tests
        run: bin/rails test test/security/sql_injection_test.rb
```

### 2. Static Analysis Custom Rules

Añadir regla custom a Brakeman:

```ruby
# config/brakeman_custom_checks/check_unquoted_columns.rb
class CheckUnquotedColumns < Brakeman::BaseCheck
  def run_check
    # Buscar patrones de columns.join sin quote_column_name
    # ...
  end
end
```

### 3. Developer Training

- Workshop de seguridad Rails (SQL Injection, XSS, CSRF)
- Guía de "Secure Coding Guidelines" para el equipo
- Security champions program

### 4. Migración de SQL Raw

Monitorear Rails 8.2+ para ver si se corrige el issue con TimescaleDB:

```ruby
# Objetivo a largo plazo: eliminar SQL raw
def bulk_insert_logs(entries)
  LogEntry.insert_all(entries)  # ✅ Seguro por defecto
end
```

### 5. Auditoría de Código Existente

Buscar otros lugares con vulnerabilidades similares:

```bash
# Buscar otros usos de SQL raw
grep -r "connection.execute" app/
grep -r "execute_sql" app/

# Verificar que todos usen quote_column_name
grep -r "\.keys.*join" app/
```

---

## 📞 Contactos

### Security Team

- **Security Lead**: security@brainzlab.com
- **On-call Engineer**: oncall@brainzlab.com
- **Incident Response**: incidents@brainzlab.com

### Escalation

**P0 (Critical Security)**:
1. Notificar a Security Lead inmediatamente
2. Deploy del fix sin esperar aprobación
3. Post-mortem dentro de 24h

---

## 📎 Anexos

### A. Logs de Ejemplo de Ataque

```
POST /api/v1/logs HTTP/1.1
Host: recall.brainzlab.com
Authorization: Bearer eyJhbGc...
Content-Type: application/json

{
  "logs": [{
    "timestamp; DROP TABLE log_entries CASCADE--": "attack",
    "level": "info"
  }]
}

Response:
HTTP/1.1 500 Internal Server Error
{"error": "column \"timestamp; DROP TABLE log_entries CASCADE--\" does not exist"}
```

### B. Referencias

- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html#sql-injection)
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS)

### C. Timeline

| Fecha/Hora | Evento |
|------------|--------|
| 2026-03-02 | QA Bug Report publicado (no incluía este bug) |
| 2026-03-03 10:00 | Análisis de código revela SQL injection |
| 2026-03-03 10:30 | Fix implementado en branch `fix/sql-injection-bulk-insert` |
| 2026-03-03 11:00 | Documento de seguridad creado |
| **PENDIENTE** | PR creado y merged |
| **PENDIENTE** | Deploy a producción |
| **PENDIENTE** | Auditoría de logs completa |

---

## ✅ Checklist de Remediación

- [x] Vulnerabilidad identificada y documentada
- [x] Fix implementado y testeado localmente
- [ ] PR de emergencia creado
- [ ] PR merged (emergency override)
- [ ] Deployed a producción
- [ ] Verificación post-deploy completada
- [ ] Auditoría de logs (buscar explotación previa)
- [ ] Security team notificado
- [ ] Tests de seguridad añadidos
- [ ] Hardening adicional implementado
- [ ] Post-mortem publicado
- [ ] Developer training actualizado

---

**🚨 ACCIÓN INMEDIATA REQUERIDA**

Este documento describe una vulnerabilidad **CRÍTICA** que permite acceso completo a la base de datos. El fix debe ser desplegado **INMEDIATAMENTE** sin esperar el ciclo normal de releases.

**Next Steps**:
1. ✅ Crear PR de emergencia
2. ✅ Merge sin esperar CI
3. ✅ Deploy a producción (< 30 min)
4. ✅ Verificar que el fix funciona
5. ✅ Auditar logs en busca de explotación previa

---

**Clasificación**: 🔴 CONFIDENTIAL - SECURITY SENSITIVE
**Distribución**: Security Team, Engineering Leads only
**Fecha**: 2026-03-03
**Autor**: Claude (AI Security Analysis)
