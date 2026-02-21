package com.example.resource;

import com.example.model.Item;
import com.example.service.ItemService;
import javax.inject.Inject;
import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import java.net.URI;
import java.util.List;
import java.util.logging.Logger;

/**
 * REST endpoint for managing Items.
 * Demonstrates a complete CRUD API.
 */
@Path("/api/items")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ItemResource {

    private static final Logger LOG = Logger.getLogger(ItemResource.class.getName());

    @Inject
    ItemService itemService;

    @GET
    public List<Item> getAll() {
        LOG.info("Getting all items");
        return itemService.findAll();
    }

    @GET
    @Path("/{id}")
    public Response getById(@PathParam("id") String id) {
        LOG.info("Getting item with id: " + id);
        return itemService.findById(id)
                .map(item -> Response.ok(item).build())
                .orElse(Response.status(Response.Status.NOT_FOUND)
                        .entity(new ErrorResponse("Item not found", "ID: " + id))
                        .build());
    }

    @POST
    public Response create(Item item) {
        LOG.info("Creating new item: " + item.getName());

        if (item.getName() == null || item.getName().isBlank()) {
            return Response.status(Response.Status.BAD_REQUEST)
                    .entity(new ErrorResponse("Validation error", "Name is required"))
                    .build();
        }

        Item created = itemService.create(item);
        return Response.created(URI.create("/api/items/" + created.getId()))
                .entity(created)
                .build();
    }

    @PUT
    @Path("/{id}")
    public Response update(@PathParam("id") String id, Item item) {
        LOG.info("Updating item with id: " + id);
        return itemService.update(id, item)
                .map(updated -> Response.ok(updated).build())
                .orElse(Response.status(Response.Status.NOT_FOUND)
                        .entity(new ErrorResponse("Item not found", "ID: " + id))
                        .build());
    }

    @DELETE
    @Path("/{id}")
    public Response delete(@PathParam("id") String id) {
        LOG.info("Deleting item with id: " + id);
        if (itemService.delete(id)) {
            return Response.noContent().build();
        }
        return Response.status(Response.Status.NOT_FOUND)
                .entity(new ErrorResponse("Item not found", "ID: " + id))
                .build();
    }

    @GET
    @Path("/count")
    public Response count() {
        return Response.ok(new CountResponse(itemService.count())).build();
    }

    // Response DTOs (using inner classes for Java 8/11 compatibility)
    public static class ErrorResponse {
        private String error;
        private String message;
        
        public ErrorResponse() {}
        
        public ErrorResponse(String error, String message) {
            this.error = error;
            this.message = message;
        }
        
        public String getError() { return error; }
        public void setError(String error) { this.error = error; }
        public String getMessage() { return message; }
        public void setMessage(String message) { this.message = message; }
    }
    
    public static class CountResponse {
        private long count;
        
        public CountResponse() {}
        
        public CountResponse(long count) {
            this.count = count;
        }
        
        public long getCount() { return count; }
        public void setCount(long count) { this.count = count; }
    }
}
