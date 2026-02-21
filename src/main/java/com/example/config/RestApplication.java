package com.example.config;

import javax.ws.rs.ApplicationPath;
import javax.ws.rs.core.Application;

/**
 * JAX-RS Application configuration.
 * Sets the base path for all REST endpoints.
 */
@ApplicationPath("/")
public class RestApplication extends Application {
    // No need to register resources manually - CDI handles discovery
}
