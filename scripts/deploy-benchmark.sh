#!/bin/bash
# =============================================================================
# Deploy e Benchmark Script per WildFly 25
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

APP_NAME="wildfly-jakarta-poc"
WILDFLY_HOME="${WILDFLY_HOME:-$HOME/wildfly-25.0.0.Final}"
BASE_URL="http://localhost:8080/${APP_NAME}"

print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

# =============================================================================
# STEP 1: BUILD
# =============================================================================
build() {
    print_header "STEP 1: BUILD APPLICAZIONE"
    
    echo -e "${YELLOW}$ mvn clean package -DskipTests${NC}"
    mvn clean package -DskipTests
    
    echo ""
    echo -e "${GREEN}WAR creato:${NC}"
    ls -lh target/${APP_NAME}.war
}

# =============================================================================
# STEP 2: DEPLOY
# =============================================================================
deploy() {
    print_header "STEP 2: DEPLOY SU WILDFLY"
    
    if [ ! -d "$WILDFLY_HOME" ]; then
        echo -e "${RED}WILDFLY_HOME non trovato: $WILDFLY_HOME${NC}"
        echo "Imposta la variabile: export WILDFLY_HOME=~/wildfly-25.0.0.Final"
        exit 1
    fi
    
    echo -e "${YELLOW}Copio WAR in deployments...${NC}"
    cp target/${APP_NAME}.war "$WILDFLY_HOME/standalone/deployments/"
    
    echo -e "${GREEN}WAR copiato in: $WILDFLY_HOME/standalone/deployments/${NC}"
    
    # Attendi il deploy
    echo -e "\n${YELLOW}Attendo il deploy...${NC}"
    for i in {1..30}; do
        if [ -f "$WILDFLY_HOME/standalone/deployments/${APP_NAME}.war.deployed" ]; then
            echo -e "${GREEN}✓ Deploy completato!${NC}"
            break
        fi
        if [ -f "$WILDFLY_HOME/standalone/deployments/${APP_NAME}.war.failed" ]; then
            echo -e "${RED}✗ Deploy fallito! Controlla i log.${NC}"
            exit 1
        fi
        sleep 1
        echo -ne "\r  Attesa: ${i}s"
    done
    echo ""
}

# =============================================================================
# STEP 3: TEST
# =============================================================================
test_endpoints() {
    print_header "STEP 3: TEST ENDPOINTS"
    
    echo -e "${YELLOW}Test Health:${NC}"
    curl -s ${BASE_URL}/health | python3 -m json.tool 2>/dev/null || curl -s ${BASE_URL}/health
    echo ""
    
    echo -e "${YELLOW}Test Info:${NC}"
    curl -s ${BASE_URL}/api/info | python3 -m json.tool 2>/dev/null || curl -s ${BASE_URL}/api/info
    echo ""
    
    echo -e "${YELLOW}Test Items:${NC}"
    curl -s ${BASE_URL}/api/items | python3 -m json.tool 2>/dev/null || curl -s ${BASE_URL}/api/items
    echo ""
    
    echo -e "${YELLOW}Test Runtime (memoria JVM):${NC}"
    curl -s ${BASE_URL}/api/info/runtime | python3 -m json.tool 2>/dev/null || curl -s ${BASE_URL}/api/info/runtime
    echo ""
}

# =============================================================================
# STEP 4: MISURA RISORSE
# =============================================================================
measure_resources() {
    print_header "STEP 4: MISURA RISORSE (RAM & CPU)"
    
    WILDFLY_PID=$(pgrep -f "jboss-modules.jar" | head -1)
    
    if [ -z "$WILDFLY_PID" ]; then
        echo -e "${RED}WildFly non in esecuzione${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}PID WildFly: $WILDFLY_PID${NC}\n"
    
    # Dettagli processo
    echo -e "${CYAN}Dettagli processo:${NC}"
    ps -p $WILDFLY_PID -o pid,ppid,%cpu,%mem,rss,vsz,etime,comm
    echo ""
    
    # Calcola valori
    RSS_KB=$(ps -p $WILDFLY_PID -o rss= | tr -d ' ')
    RSS_MB=$((RSS_KB / 1024))
    VSZ_KB=$(ps -p $WILDFLY_PID -o vsz= | tr -d ' ')
    VSZ_MB=$((VSZ_KB / 1024))
    CPU=$(ps -p $WILDFLY_PID -o %cpu= | tr -d ' ')
    MEM=$(ps -p $WILDFLY_PID -o %mem= | tr -d ' ')
    
    echo "┌─────────────────────────────────────┐"
    echo "│        RISORSE WILDFLY              │"
    echo "├─────────────────────────────────────┤"
    printf "│  RAM Residente (RSS): %8d MB  │\n" $RSS_MB
    printf "│  RAM Virtuale (VSZ):  %8d MB  │\n" $VSZ_MB
    printf "│  CPU:                 %8s %%   │\n" "$CPU"
    printf "│  MEM:                 %8s %%   │\n" "$MEM"
    echo "└─────────────────────────────────────┘"
    
    # Dimensione WAR
    if [ -f "target/${APP_NAME}.war" ]; then
        WAR_SIZE=$(du -h target/${APP_NAME}.war | cut -f1)
        echo ""
        echo -e "${CYAN}Dimensione WAR: ${GREEN}$WAR_SIZE${NC}"
    fi
}

# =============================================================================
# STEP 5: BENCHMARK
# =============================================================================
benchmark() {
    print_header "STEP 5: BENCHMARK SOTTO CARICO"
    
    WILDFLY_PID=$(pgrep -f "jboss-modules.jar" | head -1)
    
    echo -e "${CYAN}Risorse PRIMA del test:${NC}"
    RSS_BEFORE=$(($(ps -p $WILDFLY_PID -o rss= | tr -d ' ') / 1024))
    echo "RAM: ${RSS_BEFORE} MB"
    echo ""
    
    echo -e "${YELLOW}Esecuzione 1000 richieste...${NC}"
    START=$(date +%s%N)
    
    for i in {1..1000}; do
        curl -s ${BASE_URL}/api/items > /dev/null &
        
        # Limita concorrenza a 50
        if (( i % 50 == 0 )); then
            wait
            echo -ne "\r  Richieste: $i/1000"
        fi
    done
    wait
    
    END=$(date +%s%N)
    DURATION_MS=$(( (END - START) / 1000000 ))
    RPS=$(( 1000 * 1000 / DURATION_MS ))
    
    echo -e "\n"
    echo -e "${GREEN}Completato!${NC}"
    echo "  Tempo totale: ${DURATION_MS}ms"
    echo "  Richieste/sec: ~${RPS}"
    echo ""
    
    echo -e "${CYAN}Risorse DOPO il test:${NC}"
    sleep 2
    RSS_AFTER=$(($(ps -p $WILDFLY_PID -o rss= | tr -d ' ') / 1024))
    echo "RAM: ${RSS_AFTER} MB"
    echo "Delta: $((RSS_AFTER - RSS_BEFORE)) MB"
}

# =============================================================================
# CONFRONTO CON QUARKUS
# =============================================================================
compare() {
    print_header "CONFRONTO WILDFLY vs QUARKUS"
    
    WILDFLY_PID=$(pgrep -f "jboss-modules.jar" | head -1)
    WF_RSS="N/A"
    WF_WAR="N/A"
    
    if [ -n "$WILDFLY_PID" ]; then
        WF_RSS=$(($(ps -p $WILDFLY_PID -o rss= | tr -d ' ') / 1024))
    fi
    
    if [ -f "target/${APP_NAME}.war" ]; then
        WF_WAR=$(du -m target/${APP_NAME}.war | cut -f1)
    fi
    
    echo "┌───────────────────────────────────────────────────────────────────┐"
    echo "│                  CONFRONTO WILDFLY vs QUARKUS                     │"
    echo "├───────────────────┬─────────────────────┬─────────────────────────┤"
    echo "│ Metrica           │ WildFly 25          │ Quarkus (tipico)        │"
    echo "├───────────────────┼─────────────────────┼─────────────────────────┤"
    printf "│ %-17s │ %15s MB  │ %19s MB  │\n" "Dimensione App" "${WF_WAR:-~3}" "~15 (uber-jar)"
    printf "│ %-17s │ %15s MB  │ %19s MB  │\n" "RAM a Riposo" "${WF_RSS:-~300}" "~50-80"
    printf "│ %-17s │ %15s MB  │ %19s MB  │\n" "RAM sotto carico" "~400-600" "~100-150"
    printf "│ %-17s │ %15s     │ %19s     │\n" "Startup Time" "~5-15 sec" "~1-2 sec"
    printf "│ %-17s │ %15s     │ %19s     │\n" "Startup (native)" "N/A" "~0.02 sec"
    echo "├───────────────────┼─────────────────────┼─────────────────────────┤"
    printf "│ %-17s │ %15s MB  │ %19s MB  │\n" "5 istanze RAM" "~1500-2000" "~300-400"
    printf "│ %-17s │ %15s MB  │ %19s MB  │\n" "10 istanze RAM" "~3000-4000" "~600-800"
    echo "├───────────────────┼─────────────────────┼─────────────────────────┤"
    printf "│ %-17s │ %19s │ %23s │\n" "Scaling" "Load Balancer" "kubectl scale"
    printf "│ %-17s │ %19s │ %23s │\n" "Auto-scaling" "Manuale" "HPA"
    echo "└───────────────────┴─────────────────────┴─────────────────────────┘"
    
    echo ""
    echo -e "${CYAN}Conclusione:${NC}"
    echo "• Quarkus usa ~4-5x meno RAM per istanza"
    echo "• Quarkus Native usa ~10-15x meno RAM"
    echo "• Scaling in K8s è automatico e semplice"
    echo "• WildFly richiede configurazione manuale per scaling"
}

# =============================================================================
# MAIN
# =============================================================================

cd "$(dirname "$0")/.." 2>/dev/null || cd "$(dirname "$0")"

case "$1" in
    build)
        build
        ;;
    deploy)
        deploy
        ;;
    test)
        test_endpoints
        ;;
    measure)
        measure_resources
        ;;
    benchmark)
        benchmark
        ;;
    compare)
        compare
        ;;
    all)
        build
        deploy
        sleep 5
        test_endpoints
        measure_resources
        benchmark
        compare
        ;;
    *)
        echo "WildFly 25 Deploy & Benchmark"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  build     - Compila il progetto"
        echo "  deploy    - Deploy su WildFly"
        echo "  test      - Testa gli endpoint"
        echo "  measure   - Misura RAM e CPU"
        echo "  benchmark - Esegue benchmark"
        echo "  compare   - Confronta con Quarkus"
        echo "  all       - Esegue tutto in sequenza"
        echo ""
        echo "Esempio completo:"
        echo "  $0 all"
        ;;
esac
