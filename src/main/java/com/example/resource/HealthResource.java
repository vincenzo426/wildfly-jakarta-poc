package com.example.resource;

import com.example.service.ItemService;
import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Custom Health Check endpoints.
 * Emulates MicroProfile Health for WildFly 25 standalone.
 * 
 * Endpoints:
 * - /health       - All health checks
 * - /health/live  - Liveness check
 * - /health/ready - Readiness check
 */
@Path("/health")
@Produces(MediaType.APPLICATION_JSON)
public class HealthResource {

    @Inject
    ItemService itemService;

    /**
     * Combined health check (liveness + readiness)
     */
    @GET
    public Response health() {
        Map<String, Object> liveness = checkLiveness();
        Map<String, Object> readiness = checkReadiness();
        
        boolean isUp = "UP".equals(liveness.get("status")) && "UP".equals(readiness.get("status"));
        
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("status", isUp ? "UP" : "DOWN");
        
        List<Map<String, Object>> checks = new ArrayList<>();
        checks.add(liveness);
        checks.add(readiness);
        result.put("checks", checks);
        
        return Response.status(isUp ? 200 : 503).entity(result).build();
    }

    /**
     * Liveness check - is the application running?
     */
    @GET
    @Path("/live")
    public Response liveness() {
        Map<String, Object> check = checkLiveness();
        boolean isUp = "UP".equals(check.get("status"));
        
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("status", check.get("status"));
        
        List<Map<String, Object>> checks = new ArrayList<>();
        checks.add(check);
        result.put("checks", checks);
        
        return Response.status(isUp ? 200 : 503).entity(result).build();
    }

    /**
     * Readiness check - is the application ready to serve requests?
     */
    @GET
    @Path("/ready")
    public Response readiness() {
        Map<String, Object> check = checkReadiness();
        boolean isUp = "UP".equals(check.get("status"));
        
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("status", check.get("status"));
        
        List<Map<String, Object>> checks = new ArrayList<>();
        checks.add(check);
        result.put("checks", checks);
        
        return Response.status(isUp ? 200 : 503).entity(result).build();
    }

    private Map<String, Object> checkLiveness() {
        Map<String, Object> check = new LinkedHashMap<>();
        check.put("name", "Application Liveness");
        
        try {
            MemoryMXBean memoryBean = ManagementFactory.getMemoryMXBean();
            long usedHeap = memoryBean.getHeapMemoryUsage().getUsed();
            long maxHeap = memoryBean.getHeapMemoryUsage().getMax();
            
            double memoryUsagePercent = (double) usedHeap / maxHeap * 100;
            boolean isHealthy = memoryUsagePercent < 90;
            
            check.put("status", isHealthy ? "UP" : "DOWN");
            
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("heapUsedMB", usedHeap / (1024 * 1024));
            data.put("heapMaxMB", maxHeap / (1024 * 1024));
            data.put("heapUsagePercent", String.format("%.2f%%", memoryUsagePercent));
            check.put("data", data);
            
        } catch (Exception e) {
            check.put("status", "DOWN");
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("error", e.getMessage());
            check.put("data", data);
        }
        
        return check;
    }

    private Map<String, Object> checkReadiness() {
        Map<String, Object> check = new LinkedHashMap<>();
        check.put("name", "Item Service Readiness");
        
        try {
            boolean serviceHealthy = itemService != null && itemService.isHealthy();
            long itemCount = serviceHealthy ? itemService.count() : 0;
            
            check.put("status", serviceHealthy ? "UP" : "DOWN");
            
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("itemCount", itemCount);
            data.put("serviceAvailable", serviceHealthy);
            check.put("data", data);
            
        } catch (Exception e) {
            check.put("status", "DOWN");
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("error", e.getMessage());
            check.put("data", data);
        }
        
        return check;
    }
}
