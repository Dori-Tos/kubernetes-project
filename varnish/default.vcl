vcl 4.1;

# Backend configuration - points to your Flask service
backend default {
    .host = "app-service";  # Your Flask service name
    .port = "8080";          # Your Flask service port
    .connect_timeout = 60s;
    .first_byte_timeout = 60s;
    .between_bytes_timeout = 60s;
    .max_connections = 50;
}

# Health check for backend
probe healthcheck {
    .url = "/";
    .timeout = 5s;
    .interval = 10s;
    .window = 5;
    .threshold = 3;
}

# Configure the backend with health check
backend flask_backend {
    .host = "app-service";
    .port = "8080";
    .probe = healthcheck;
}

sub vcl_recv {
    # Set backend
    set req.backend_hint = flask_backend;
    
    # Remove cookies for static content (if any)
    if (req.url ~ "\.(css|js|png|jpg|jpeg|gif|ico|svg)$") {
        unset req.http.Cookie;
    }
    
    # Handle different request methods
    if (req.method != "GET" && req.method != "HEAD" && req.method != "PUT" && req.method != "POST" && req.method != "TRACE" && req.method != "OPTIONS" && req.method != "DELETE") {
        return (pipe);
    }
    
    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
    
    return (hash);
}

sub vcl_backend_response {
    # Set cache TTL for different content types
    if (bereq.url ~ "\.(css|js|png|jpg|jpeg|gif|ico|svg)$") {
        set beresp.ttl = 1h;  # Cache static files for 1 hour
    } else if (beresp.http.Content-Type ~ "text/html") {
        set beresp.ttl = 60s; # Cache HTML for 1 minute
    } else {
        set beresp.ttl = 300s; # Cache other content for 5 minutes
    }
    
    # Remove cookies from cached objects
    if (bereq.url ~ "\.(css|js|png|jpg|jpeg|gif|ico|svg)$") {
        unset beresp.http.Set-Cookie;
    }
    
    return (deliver);
}

sub vcl_deliver {
    # Add cache status header for debugging
    if (obj.hits > 0) {
        set resp.http.X-Varnish-Cache = "HIT";
    } else {
        set resp.http.X-Varnish-Cache = "MISS";
    }
    
    # Add cache hits count
    set resp.http.X-Varnish-Hits = obj.hits;
    
    return (deliver);
}

sub vcl_hash {
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    return (lookup);
}