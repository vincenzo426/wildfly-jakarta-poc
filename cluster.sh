#!/bin/bash
# =============================================================================
# WildFly Cluster - Script di Gestione e Benchmark
# =============================================================================
#
# Uso:
#   ./cluster.sh start 5       # Avvia cluster con 5 istanze
#   ./cluster.sh stop          # Ferma il cluster
#   ./cluster.sh status        # Mostra stato del cluster
#   ./cluster.sh scale 10      # Scala a 10 istanze
#   ./cluster.sh benchmark     # Esegue benchmark
#   ./cluster.sh measure       # Misura risorse
#   ./cluster.sh compare 5     # Confronta 5 istanze vs Quarkus
#   ./cluster.sh logs          # Mostra logs
#   ./cluster.sh full-test 5   # Test completo con 5 istanze
#
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

APP_NAME="wildfly-jakarta-poc"
BASE_URL="http://localhost:8080/${APP_NAME}"

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# =============================================================================
# BUILD
# =============================================================================
build() {
    print_header "BUILD APPLICAZIONE"
    
    echo -e "${YELLOW}Compilazione Maven...${NC}"
    mvn clean package -DskipTests -q
    
    echo -e "${GREEN}✓ WAR creato: target/${APP_NAME}.war${NC}"
    ls -lh target/${APP_NAME}.war
}

# =============================================================================
# START CLUSTER
# =============================================================================
start_cluster() {
    local INSTANCES=${1:-3}
    
    print_header "AVVIO CLUSTER CON $INSTANCES ISTANZE"
    
    # Build se necessario
    if [ ! -f "target/${APP_NAME}.war" ]; then
        build
    fi
    
    echo -e "${YELLOW}Build immagine Docker...${NC}"
    docker-compose build --quiet
    
    echo -e "${YELLOW}Avvio $INSTANCES istanze WildFly + Nginx...${NC}"
    docker-compose up -d --scale wildfly=$INSTANCES
    
    echo -e "\n${YELLOW}Attendo che il cluster sia pronto...${NC}"
    
    # Attendi che Nginx risponda
    for i in {1..90}; do
        if curl -s "http://localhost:8080/${APP_NAME}/health/ready" 2>/dev/null | grep -q "UP"; then
            echo -e "\n${GREEN}✓ Cluster pronto!${NC}"
            break
        fi
        echo -ne "\r  Attesa: ${i}s"
        sleep 1
    done
    
    echo ""
    status
}

# =============================================================================
# STOP CLUSTER
# =============================================================================
stop_cluster() {
    print_header "STOP CLUSTER"
    
    docker-compose down
    
    echo -e "${GREEN}✓ Cluster fermato${NC}"
}

# =============================================================================
# SCALE
# =============================================================================
scale_cluster() {
    local INSTANCES=${1:-3}
    
    print_header "SCALING A $INSTANCES ISTANZE"
    
    docker-compose up -d --scale wildfly=$INSTANCES --no-recreate
    
    sleep 5
    status
}

# =============================================================================
# STATUS
# =============================================================================
status() {
    print_header "STATO DEL CLUSTER"
    
    echo -e "${CYAN}Container attivi:${NC}"
    docker-compose ps
    
    echo ""
    
    # Conta istanze WildFly
    WILDFLY_COUNT=$(docker-compose ps -q wildfly 2>/dev/null | wc -l)
    echo -e "${GREEN}Istanze WildFly attive: $WILDFLY_COUNT${NC}"
    
    # Test load balancer
    echo -e "\n${CYAN}Test Load Balancer (10 richieste):${NC}"
    for i in {1..10}; do
        RESPONSE=$(curl -s -I "http://localhost:8081/${APP_NAME}/api/info" 2>/dev/null | grep -i "X-Upstream-Addr" || echo "N/A")
        echo "  Richiesta $i: $RESPONSE"
    done
}

# =============================================================================
# MEASURE RESOURCES
# =============================================================================
measure_resources() {
    print_header "MISURA RISORSE CLUSTER"
    
    # Conta istanze
    WILDFLY_COUNT=$(docker-compose ps -q wildfly 2>/dev/null | wc -l)
    
    echo -e "${CYAN}Istanze WildFly: $WILDFLY_COUNT${NC}\n"
    
    # Header tabella
    echo "┌────────────────────────────────────┬────────┬────────────┬────────────┐"
    echo "│ Container                          │ CPU %  │ RAM (MB)   │ RAM Limit  │"
    echo "├────────────────────────────────────┼────────┼────────────┼────────────┤"
    
    TOTAL_CPU=0
    TOTAL_RAM=0
    
    # Stats per ogni container
    while read -r line; do
        CONTAINER=$(echo "$line" | awk '{print $1}')
        CPU=$(echo "$line" | awk '{print $2}' | tr -d '%')
        RAM=$(echo "$line" | awk '{print $3}')
        RAM_LIMIT=$(echo "$line" | awk '{print $4}')
        
        # Converti RAM in MB
        RAM_MB=$(echo "$RAM" | sed 's/MiB//g' | sed 's/GiB/*1024/g' | bc 2>/dev/null || echo "0")
        
        printf "│ %-34s │ %6s │ %10s │ %10s │\n" "$CONTAINER" "$CPU%" "$RAM" "$RAM_LIMIT"
        
        # Somma totali (solo per WildFly)
        if [[ "$CONTAINER" == *"wildfly"* ]]; then
            TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc 2>/dev/null || echo "0")
            TOTAL_RAM=$(echo "$TOTAL_RAM + $RAM_MB" | bc 2>/dev/null || echo "0")
        fi
    done < <(docker stats --no-stream --format "{{.Name}} {{.CPUPerc}} {{.MemUsage}}" 2>/dev/null | grep -E "wildfly|nginx")
    
    echo "├────────────────────────────────────┼────────┼────────────┼────────────┤"
    printf "│ ${GREEN}%-34s${NC} │ ${GREEN}%6s${NC} │ ${GREEN}%7.0f MB${NC} │            │\n" "TOTALE WILDFLY" "${TOTAL_CPU}%" "$TOTAL_RAM"
    echo "└────────────────────────────────────┴────────┴────────────┴────────────┘"
    
    # Calcola media
    if [ "$WILDFLY_COUNT" -gt 0 ]; then
        AVG_RAM=$(echo "scale=0; $TOTAL_RAM / $WILDFLY_COUNT" | bc 2>/dev/null || echo "0")
        echo ""
        echo -e "${CYAN}Media RAM per istanza: ${GREEN}${AVG_RAM} MB${NC}"
    fi
    
    # Esporta per confronto
    export MEASURED_INSTANCES=$WILDFLY_COUNT
    export MEASURED_TOTAL_RAM=$TOTAL_RAM
}

# =============================================================================
# BENCHMARK
# =============================================================================
benchmark() {
    print_header "BENCHMARK SOTTO CARICO"
    
    WILDFLY_COUNT=$(docker-compose ps -q wildfly 2>/dev/null | wc -l)
    echo -e "${CYAN}Istanze attive: $WILDFLY_COUNT${NC}\n"
    
    # Misura prima
    echo -e "${YELLOW}Risorse PRIMA del test:${NC}"
    docker stats --no-stream --format "{{.Name}}: {{.MemUsage}}" 2>/dev/null | grep wildfly | head -3
    echo ""
    
    # Test
    REQUESTS=5000
    CONCURRENCY=50
    
    if command -v wrk &> /dev/null; then
        echo -e "${YELLOW}Benchmark con wrk (30 secondi):${NC}"
        wrk -t4 -c$CONCURRENCY -d30s "http://localhost:8081/${APP_NAME}/api/items"
    elif command -v ab &> /dev/null; then
        echo -e "${YELLOW}Benchmark con ab ($REQUESTS richieste, $CONCURRENCY concorrenti):${NC}"
        ab -n $REQUESTS -c $CONCURRENCY "http://localhost:8081/${APP_NAME}/api/items"
    else
        echo -e "${YELLOW}Benchmark con curl ($REQUESTS richieste):${NC}"
        START=$(date +%s%N)
        
        for i in $(seq 1 $REQUESTS); do
            curl -s "http://localhost:8081/${APP_NAME}/api/items" > /dev/null &
            
            if (( i % $CONCURRENCY == 0 )); then
                wait
                echo -ne "\r  Completate: $i/$REQUESTS"
            fi
        done
        wait
        
        END=$(date +%s%N)
        DURATION_MS=$(( (END - START) / 1000000 ))
        RPS=$(( REQUESTS * 1000 / DURATION_MS ))
        
        echo -e "\n"
        echo "  Tempo totale: ${DURATION_MS}ms"
        echo "  Richieste/sec: ~${RPS}"
    fi
    
    # Misura dopo
    echo -e "\n${YELLOW}Risorse DOPO il test:${NC}"
    sleep 2
    docker stats --no-stream --format "{{.Name}}: {{.MemUsage}}" 2>/dev/null | grep wildfly | head -3
}

# =============================================================================
# COMPARE WITH QUARKUS
# =============================================================================
compare() {
    local INSTANCES=${1:-10}
    
    print_header "CONFRONTO: $INSTANCES ISTANZE WILDFLY vs QUARKUS"
    
    # Misura se cluster attivo
    WILDFLY_COUNT=$(docker-compose ps -q wildfly 2>/dev/null | wc -l)
    
    if [ "$WILDFLY_COUNT" -gt 0 ]; then
        measure_resources > /dev/null 2>&1
        WF_TOTAL=$MEASURED_TOTAL_RAM
        WF_AVG=$(echo "scale=0; $WF_TOTAL / $WILDFLY_COUNT" | bc 2>/dev/null || echo "300")
        INSTANCES=$WILDFLY_COUNT
    else
        WF_AVG=300
        WF_TOTAL=$((WF_AVG * INSTANCES))
    fi
    
    # Valori Quarkus tipici
    QK_JVM_AVG=64
    QK_JVM_TOTAL=$((QK_JVM_AVG * INSTANCES))
    
    QK_NATIVE_AVG=20
    QK_NATIVE_TOTAL=$((QK_NATIVE_AVG * INSTANCES))
    
    echo "┌─────────────────────────────────────────────────────────────────────────┐"
    echo "│           CONFRONTO RISORSE: $INSTANCES ISTANZE/REPLICHE                         │"
    echo "├─────────────────────┬───────────────────┬───────────────┬───────────────┤"
    echo "│                     │ WildFly 25        │ Quarkus JVM   │ Quarkus Native│"
    echo "├─────────────────────┼───────────────────┼───────────────┼───────────────┤"
    printf "│ %-19s │ %13d MB  │ %9d MB  │ %9d MB  │\n" "RAM per istanza" "$WF_AVG" "$QK_JVM_AVG" "$QK_NATIVE_AVG"
    printf "│ %-19s │ ${RED}%13d MB${NC}  │ ${YELLOW}%9d MB${NC}  │ ${GREEN}%9d MB${NC}  │\n" "RAM TOTALE ($INSTANCES ist.)" "$WF_TOTAL" "$QK_JVM_TOTAL" "$QK_NATIVE_TOTAL"
    printf "│ %-19s │ %13s     │ %13s │ %13s │\n" "Startup/istanza" "~8-15 sec" "~1-2 sec" "~0.02 sec"
    echo "├─────────────────────┼───────────────────┼───────────────┼───────────────┤"
    printf "│ %-19s │ %17s │ %13s │ %13s │\n" "Scaling" "docker scale" "kubectl scale" "kubectl scale"
    printf "│ %-19s │ %17s │ %13s │ %13s │\n" "Load Balancer" "Nginx (manuale)" "K8s Service" "K8s Service"
    printf "│ %-19s │ %17s │ %13s │ %13s │\n" "Auto-scaling" "No" "HPA" "HPA"
    echo "└─────────────────────┴───────────────────┴───────────────┴───────────────┘"
    
    echo ""
    
    # Calcola differenze
    DIFF_JVM=$((WF_TOTAL - QK_JVM_TOTAL))
    DIFF_NATIVE=$((WF_TOTAL - QK_NATIVE_TOTAL))
    RATIO_JVM=$(echo "scale=1; $WF_TOTAL / $QK_JVM_TOTAL" | bc)
    RATIO_NATIVE=$(echo "scale=1; $WF_TOTAL / $QK_NATIVE_TOTAL" | bc)
    
    echo -e "${CYAN}Analisi:${NC}"
    echo -e "• WildFly usa ${RED}${DIFF_JVM} MB in più${NC} rispetto a Quarkus JVM (${RATIO_JVM}x)"
    echo -e "• WildFly usa ${RED}${DIFF_NATIVE} MB in più${NC} rispetto a Quarkus Native (${RATIO_NATIVE}x)"
    
    # Stima costi cloud
    echo -e "\n${CYAN}Stima costi mensili (AWS-like, ~\$0.05/GB/ora):${NC}"
    WF_COST=$(echo "scale=2; $WF_TOTAL / 1024 * 0.05 * 720" | bc)
    QK_JVM_COST=$(echo "scale=2; $QK_JVM_TOTAL / 1024 * 0.05 * 720" | bc)
    QK_NATIVE_COST=$(echo "scale=2; $QK_NATIVE_TOTAL / 1024 * 0.05 * 720" | bc)
    
    echo "• WildFly:       ~\$${WF_COST}/mese"
    echo "• Quarkus JVM:   ~\$${QK_JVM_COST}/mese"
    echo "• Quarkus Native: ~\$${QK_NATIVE_COST}/mese"
}

# =============================================================================
# LOGS
# =============================================================================
show_logs() {
    print_header "LOGS DEL CLUSTER"
    
    docker-compose logs --tail=50 -f
}

# =============================================================================
# TEST COMPLETO
# =============================================================================
full_test() {
    local INSTANCES=${1:-5}
    
    print_header "TEST COMPLETO CON $INSTANCES ISTANZE"
    
    # Step 1: Build
    build
    
    # Step 2: Start cluster
    start_cluster $INSTANCES
    
    # Step 3: Attendi stabilizzazione
    echo -e "\n${YELLOW}Attendo stabilizzazione (30s)...${NC}"
    sleep 30
    
    # Step 4: Test endpoints
    print_header "TEST ENDPOINTS"
    echo -e "${YELLOW}Health:${NC}"
    curl -s "${BASE_URL}/health" | python3 -m json.tool 2>/dev/null || curl -s "${BASE_URL}/health"
    echo ""
    
    echo -e "${YELLOW}Info:${NC}"
    curl -s "${BASE_URL}/api/info" | python3 -m json.tool 2>/dev/null || curl -s "${BASE_URL}/api/info"
    echo ""
    
    # Step 5: Misura risorse
    measure_resources
    
    # Step 6: Benchmark
    benchmark
    
    # Step 7: Confronto
    compare $INSTANCES
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  TEST COMPLETO TERMINATO${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Il cluster è ancora attivo. Comandi utili:"
    echo "  ./cluster.sh status    - Stato cluster"
    echo "  ./cluster.sh scale N   - Scala a N istanze"
    echo "  ./cluster.sh measure   - Misura risorse"
    echo "  ./cluster.sh stop      - Ferma cluster"
}

# =============================================================================
# HELP
# =============================================================================
show_help() {
    echo "WildFly Cluster Manager"
    echo ""
    echo "Uso: $0 <comando> [opzioni]"
    echo ""
    echo "Comandi:"
    echo "  start [N]      Avvia cluster con N istanze (default: 3)"
    echo "  stop           Ferma il cluster"
    echo "  status         Mostra stato del cluster"
    echo "  scale N        Scala a N istanze"
    echo "  measure        Misura RAM e CPU"
    echo "  benchmark      Esegue benchmark di carico"
    echo "  compare [N]    Confronta N istanze vs Quarkus"
    echo "  logs           Mostra logs (Ctrl+C per uscire)"
    echo "  full-test [N]  Test completo con N istanze"
    echo ""
    echo "Esempi:"
    echo "  $0 start 5          # Avvia 5 istanze"
    echo "  $0 scale 10         # Scala a 10 istanze"
    echo "  $0 full-test 5      # Test completo con 5 istanze"
}

# =============================================================================
# MAIN
# =============================================================================

cd "$(dirname "$0")"

case "$1" in
    start)
        start_cluster ${2:-3}
        ;;
    stop)
        stop_cluster
        ;;
    status)
        status
        ;;
    scale)
        scale_cluster ${2:-3}
        ;;
    measure)
        measure_resources
        ;;
    benchmark)
        benchmark
        ;;
    compare)
        compare ${2:-5}
        ;;
    logs)
        show_logs
        ;;
    full-test)
        full_test ${2:-5}
        ;;
    build)
        build
        ;;
    *)
        show_help
        ;;
esac
