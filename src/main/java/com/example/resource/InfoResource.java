package com.example.resource;

import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

import java.lang.management.ManagementFactory;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Application info endpoint.
 * Useful for debugging and verification.
 */
@Path("/api/info")
@Produces(MediaType.APPLICATION_JSON)
public class InfoResource {

    private static final Instant START_TIME = Instant.now();

    @GET
    public Map<String, Object> getInfo() {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("application", "wildfly-jakarta-poc");
        info.put("version", "1.0.0");
        info.put("framework", "Jakarta EE 8");
        info.put("server", "WildFly 25");
        info.put("startTime", START_TIME.toString());
        info.put("uptime", Duration.between(START_TIME, Instant.now()).toSeconds() + " seconds");
        info.put("javaVersion", System.getProperty("java.version"));
        info.put("javaVendor", System.getProperty("java.vendor"));
        info.put("osName", System.getProperty("os.name"));
        info.put("hostname", getHostname());
        info.put("timestamp", Instant.now().toString());
        return info;
    }

    @GET
    @Path("/env")
    public Map<String, String> getEnvironment() {
        Map<String, String> env = new LinkedHashMap<>();
        env.put("HOSTNAME", System.getenv().getOrDefault("HOSTNAME", getHostname()));
        env.put("JBOSS_HOME", System.getenv().getOrDefault("JBOSS_HOME", "not-set"));
        env.put("JAVA_HOME", System.getenv().getOrDefault("JAVA_HOME", "not-set"));
        env.put("TZ", System.getenv().getOrDefault("TZ", "UTC"));
        env.put("USER", System.getProperty("user.name"));
        return env;
    }

    @GET
    @Path("/runtime")
    public Map<String, Object> getRuntime() {
        Runtime runtime = Runtime.getRuntime();
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("availableProcessors", runtime.availableProcessors());
        info.put("freeMemoryMB", runtime.freeMemory() / (1024 * 1024));
        info.put("totalMemoryMB", runtime.totalMemory() / (1024 * 1024));
        info.put("maxMemoryMB", runtime.maxMemory() / (1024 * 1024));
        info.put("usedMemoryMB", (runtime.totalMemory() - runtime.freeMemory()) / (1024 * 1024));
        info.put("uptimeSeconds", ManagementFactory.getRuntimeMXBean().getUptime() / 1000);
        return info;
    }

    private String getHostname() {
        try {
            return java.net.InetAddress.getLocalHost().getHostName();
        } catch (Exception e) {
            return "unknown";
        }
    }
}
