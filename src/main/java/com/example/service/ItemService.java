package com.example.service;

import com.example.model.Item;
import javax.annotation.PostConstruct;
import javax.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Logger;

/**
 * In-memory service for managing Items.
 * Uses CDI for dependency injection.
 * In a real application, this would use JPA/Hibernate.
 */
@ApplicationScoped
public class ItemService {

    private static final Logger LOG = Logger.getLogger(ItemService.class.getName());
    
    private final Map<String, Item> items = new ConcurrentHashMap<>();

    @PostConstruct
    void init() {
        LOG.info("Initializing ItemService with sample data");
        
        // Add some sample data
        Item item1 = new Item("Laptop", "High-performance laptop for developers", 1299.99);
        Item item2 = new Item("Keyboard", "Mechanical keyboard with RGB", 149.99);
        Item item3 = new Item("Monitor", "27-inch 4K monitor", 449.99);

        items.put(item1.getId(), item1);
        items.put(item2.getId(), item2);
        items.put(item3.getId(), item3);
        
        LOG.info("ItemService initialized with " + items.size() + " items");
    }

    public List<Item> findAll() {
        return new ArrayList<>(items.values());
    }

    public Optional<Item> findById(String id) {
        return Optional.ofNullable(items.get(id));
    }

    public Item create(Item item) {
        if (item.getId() == null || item.getId().isBlank()) {
            item = new Item(item.getName(), item.getDescription(), item.getPrice());
        }
        items.put(item.getId(), item);
        LOG.info("Created item: " + item.getId());
        return item;
    }

    public Optional<Item> update(String id, Item updatedItem) {
        return findById(id).map(existing -> {
            existing.setName(updatedItem.getName());
            existing.setDescription(updatedItem.getDescription());
            existing.setPrice(updatedItem.getPrice());
            existing.setUpdatedAt(Instant.now());
            LOG.info("Updated item: " + id);
            return existing;
        });
    }

    public boolean delete(String id) {
        boolean removed = items.remove(id) != null;
        if (removed) {
            LOG.info("Deleted item: " + id);
        }
        return removed;
    }

    public long count() {
        return items.size();
    }
    
    /**
     * Check if the service is healthy.
     * Used by health checks.
     */
    public boolean isHealthy() {
        try {
            // Simple health check - verify the map is accessible
            items.size();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
