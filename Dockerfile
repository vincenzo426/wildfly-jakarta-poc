# =============================================================================
# Dockerfile per WildFly 26 + Jakarta EE 8 PoC
# =============================================================================
# WildFly 26 è l'ultima versione con Jakarta EE 8 (namespace javax.*)
# Compatibile con la nostra PoC senza modifiche
# =============================================================================
FROM quay.io/wildfly/wildfly:26.1.3.Final-jdk11

LABEL maintainer="example@example.com"
LABEL description="WildFly 26 Jakarta EE 8 PoC"
LABEL version="1.0.0"

# Copia il WAR nell'immagine
COPY target/wildfly-jakarta-poc.war /opt/jboss/wildfly/standalone/deployments/

# Esponi le porte
# 8080 - HTTP
# 9990 - Management Console
EXPOSE 8080 9990

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/wildfly-jakarta-poc/health/ready || exit 1

# Avvia WildFly
# -b 0.0.0.0 = bind su tutte le interfacce (necessario per Docker)
# -bmanagement 0.0.0.0 = bind management su tutte le interfacce
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]