# =============================================================================
# iDempiere ERP - ARM64 Docker Image (built from source)
# =============================================================================
# Two-stage build:
#   Stage 1 (builder): Maven + JDK 17 → compile iDempiere from source
#   Stage 2 (runtime): JRE 17 only → minimal production image
#
# Usage:
#   docker build -t idempiere:13-arm64 -f docker/Dockerfile .
#   docker build --build-arg IDEMPIERE_SOURCE=prebuilt \
#     -t idempiere:13-arm64 -f docker/Dockerfile .
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build from source
# ---------------------------------------------------------------------------
FROM eclipse-temurin:17-jdk-noble AS builder

# NOTE: We use ./mvnw (Maven Wrapper) instead of system maven.
# The wrapper auto-downloads Maven 3.9.10 (see .mvn/wrapper/maven-wrapper.properties),
# which satisfies Tycho 4.0.8's requirement of Maven >= 3.9.0.
# Ubuntu Noble's apt maven package is only 3.8.7 — too old.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /source

# Copy source tree (use .dockerignore to exclude unnecessary files)
COPY . .

# Build iDempiere — full verify including product materialization
# Uses ./mvnw to get Maven 3.9.10 (required by Tycho 4.0.8)
# The ARM64 antrun plugin in org.idempiere.p2/pom.xml removes QUIC jars
RUN ./mvnw verify -U -ntp \
    -DskipTests=true \
    -Dtycho.disableP2Mirrors=true

# Extract the built server product for linux/gtk/aarch64
# Tycho materializes files directly into the aarch64/ directory (no idempiere-server subdir)
RUN PRODUCT_DIR=$(find org.idempiere.p2/target/products -type d -name "aarch64" | head -1) && \
    if [ -z "$PRODUCT_DIR" ]; then \
      echo "ERROR: aarch64 build output not found. Available:"; \
      find org.idempiere.p2/target/products -maxdepth 4 -type d; \
      exit 1; \
    fi && \
    echo "Found product at: $PRODUCT_DIR" && \
    mv "$PRODUCT_DIR" /opt/idempiere

# ---------------------------------------------------------------------------
# Stage 2: Runtime image (JRE only, ~60% smaller)
# ---------------------------------------------------------------------------
FROM eclipse-temurin:17-jre-noble AS runtime

LABEL maintainer="dalcontak"
LABEL org.opencontainers.image.title="iDempiere ERP (ARM64)"
LABEL org.opencontainers.image.description="iDempiere 12 ERP built for ARM64/aarch64"
LABEL org.opencontainers.image.source="https://github.com/dalcontak/idempiere"

ENV IDEMPIERE_HOME=/opt/idempiere
ENV IDEMPIERE_PLUGINS_HOME=$IDEMPIERE_HOME/plugins
ENV IDEMPIERE_LOGS_HOME=$IDEMPIERE_HOME/log

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      postgresql-client \
      curl \
      nano \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r idempiere && \
    useradd -r -g idempiere -d $IDEMPIERE_HOME -s /bin/bash idempiere

# Copy built server from builder stage
COPY --from=builder --chown=idempiere:idempiere /opt/idempiere $IDEMPIERE_HOME

# Copy entrypoint script
COPY --chown=idempiere:idempiere docker/docker-entrypoint.sh $IDEMPIERE_HOME/

# Ensure scripts are executable
RUN chmod +x $IDEMPIERE_HOME/docker-entrypoint.sh && \
    find $IDEMPIERE_HOME -name '*.sh' -exec chmod +x {} \;

# Create log directory
RUN mkdir -p $IDEMPIERE_HOME/log && \
    chown -R idempiere:idempiere $IDEMPIERE_HOME

USER idempiere
WORKDIR $IDEMPIERE_HOME

# HTTP, HTTPS, OSGi console
EXPOSE 8080 8443 12612

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["idempiere"]
