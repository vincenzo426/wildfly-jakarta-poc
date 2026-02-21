# WildFly Jakarta EE 8 PoC

Una Proof of Concept di un servizio REST Jakarta EE 8 per **WildFly 25**.

## 🚀 Quick Start - Cluster con Docker

```bash
# 1. Avvia cluster con 5 istanze
./cluster.sh start 5

# 2. Testa
curl http://localhost:8080/wildfly-jakarta-poc/api/items

# 3. Misura risorse
./cluster.sh measure

# 4. Confronta con Quarkus
./cluster.sh compare 5

# 5. Scala a 10 istanze
./cluster.sh scale 10

# 6. Ferma
./cluster.sh stop
```

## 🚀 Features

- **REST API** completa con operazioni CRUD (JAX-RS)
- **Health checks** custom (compatibili con WildFly 25)
- **CDI** per dependency injection
- **Compatibile con WildFly 25.x**

## 📁 Struttura del Progetto

```
wildfly-jakarta-poc-ee8/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/com/example/
│   │   │   ├── config/
│   │   │   │   └── RestApplication.java
│   │   │   ├── model/
│   │   │   │   └── Item.java
│   │   │   ├── service/
│   │   │   │   └── ItemService.java
│   │   │   └── resource/
│   │   │       ├── ItemResource.java
│   │   │       ├── InfoResource.java
│   │   │       └── HealthResource.java
│   │   └── webapp/
│   │       └── WEB-INF/
│   │           └── beans.xml
│   └── test/
└── README.md
```

## 🛠️ Prerequisites

- **Java 11+**
- **Maven 3.6+**
- **WildFly 25** installato

## ⚡ Quick Start

### 1. Build dell'Applicazione

```bash
cd wildfly-jakarta-poc-ee8
mvn clean package
```

### 2. Verifica che WildFly sia avviato

```bash
# WildFly dovrebbe essere già in esecuzione su:
# - HTTP: http://localhost:8080
# - Console: http://localhost:9990
```

### 3. Deploy dell'Applicazione

**Metodo 1: Copia manuale (più semplice)**

```bash
cp target/wildfly-jakarta-poc.war ~/wildfly-25.0.0.Final/standalone/deployments/
```

**Metodo 2: Via WildFly CLI**

```bash
~/wildfly-25.0.0.Final/bin/jboss-cli.sh --connect --command="deploy target/wildfly-jakarta-poc.war --force"
```

**Metodo 3: Via Console Web**

1. Vai su http://localhost:9990
2. Login con le credenziali create
3. Deployments → Add → Upload deployment
4. Seleziona `target/wildfly-jakarta-poc.war`

### 4. Test dell'Applicazione

```bash
# Lista items
curl http://localhost:8080/wildfly-jakarta-poc/api/items

# Info applicazione
curl http://localhost:8080/wildfly-jakarta-poc/api/info

# Runtime info (memoria)
curl http://localhost:8080/wildfly-jakarta-poc/api/info/runtime

# Health check completo
curl http://localhost:8080/wildfly-jakarta-poc/health

# Liveness
curl http://localhost:8080/wildfly-jakarta-poc/health/live

# Readiness
curl http://localhost:8080/wildfly-jakarta-poc/health/ready

# Crea un item
curl -X POST http://localhost:8080/wildfly-jakarta-poc/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Test item","price":99.99}'

# Conta items
curl http://localhost:8080/wildfly-jakarta-poc/api/items/count
```

## 📡 Endpoints API

| Metodo | Endpoint | Descrizione |
|--------|----------|-------------|
| GET | `/api/items` | Lista tutti gli items |
| GET | `/api/items/{id}` | Ottiene un item per ID |
| POST | `/api/items` | Crea un nuovo item |
| PUT | `/api/items/{id}` | Aggiorna un item |
| DELETE | `/api/items/{id}` | Elimina un item |
| GET | `/api/items/count` | Conta gli items |
| GET | `/api/info` | Info applicazione |
| GET | `/api/info/env` | Info ambiente |
| GET | `/api/info/runtime` | Info runtime JVM |

### Health Endpoints

| Endpoint | Descrizione |
|----------|-------------|
| `/health` | Health check completo |
| `/health/live` | Liveness probe |
| `/health/ready` | Readiness probe |

## 🔧 Comandi Utili

```bash
# Build
mvn clean package

# Deploy via CLI
~/wildfly-25.0.0.Final/bin/jboss-cli.sh --connect \
  --command="deploy target/wildfly-jakarta-poc.war --force"

# Undeploy
~/wildfly-25.0.0.Final/bin/jboss-cli.sh --connect \
  --command="undeploy wildfly-jakarta-poc.war"

# Verifica deployment
~/wildfly-25.0.0.Final/bin/jboss-cli.sh --connect \
  --command="deployment-info"

# Restart WildFly
~/wildfly-25.0.0.Final/bin/jboss-cli.sh --connect \
  --command="shutdown --restart=true"
```

## 📊 Misurare Risorse

```bash
# Trova PID di WildFly
pgrep -f "jboss-modules.jar"

# Misura RAM e CPU
ps -p $(pgrep -f "jboss-modules.jar") -o pid,%cpu,%mem,rss,vsz

# RAM in MB
echo "RAM: $(( $(ps -p $(pgrep -f jboss-modules.jar) -o rss=) / 1024 )) MB"

# Monitoraggio continuo
watch -n 2 'ps -p $(pgrep -f jboss-modules.jar) -o pid,%cpu,%mem,rss'
```

## 🐳 Cluster Docker (Scaling Orizzontale)

### Prerequisiti
- Docker
- Docker Compose

### Architettura del Cluster

```
                    ┌─────────────────────┐
                    │    Nginx (LB)       │
                    │    porta 8080       │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │  WildFly 1  │     │  WildFly 2  │     │  WildFly N  │
    │   ~300 MB   │     │   ~300 MB   │     │   ~300 MB   │
    └─────────────┘     └─────────────┘     └─────────────┘
```

### Comandi Cluster

```bash
# Build e avvia 5 istanze
./cluster.sh start 5

# Stato del cluster
./cluster.sh status

# Scala a 10 istanze
./cluster.sh scale 10

# Misura RAM e CPU
./cluster.sh measure

# Benchmark sotto carico
./cluster.sh benchmark

# Confronta con Quarkus
./cluster.sh compare 5

# Test completo automatico
./cluster.sh full-test 5

# Ferma il cluster
./cluster.sh stop

# Logs
./cluster.sh logs
```

### Verifica Load Balancing

```bash
# Ogni richiesta va a un'istanza diversa
for i in {1..5}; do
  curl -s -I http://localhost:8080/wildfly-jakarta-poc/api/info | grep X-Upstream
done
```

## 📊 Confronto WildFly vs Quarkus

| Metrica | WildFly (5 ist.) | Quarkus JVM (5 pod) | Quarkus Native (5 pod) |
|---------|------------------|---------------------|------------------------|
| **RAM Totale** | ~1500 MB | ~320 MB | ~100 MB |
| **RAM/istanza** | ~300 MB | ~64 MB | ~20 MB |
| **Startup** | ~8-15 sec | ~1-2 sec | ~0.02 sec |
| **Scaling** | docker scale | kubectl scale | kubectl scale |
| **Auto-scaling** | Manuale | HPA | HPA |

## 📝 Note

- Questa versione usa **Jakarta EE 8** (namespace `javax.*`)
- Compatibile con **WildFly 23, 24, 25, 26**
- I health check sono implementati come endpoint REST custom
- Per WildFly 27+ usare la versione Jakarta EE 10
- Il cluster Docker usa Nginx come load balancer
