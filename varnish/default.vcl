vcl 4.1;

backend default {
    .host = "app-service";
    .port = "8080";
    .first_byte_timeout = 300s;
}

sub vcl_recv {
    # Remove cookies for GET requests without session cookies
    if (req.method == "GET" && req.http.Cookie !~ "sessionid") {
        unset req.http.Cookie;
    }
    
    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
    
    return (hash);
}

sub vcl_backend_response {
    # Cache API endpoints for shorter time
    if (bereq.url ~ "^/(actors|reviews)") {
        set beresp.ttl = 5m;  # API endpoints cache for 5 minutes
    } else if (bereq.url == "/") {
        set beresp.ttl = 1h;  # Home page cache for 1 hour
    } else {
        set beresp.ttl = 30m; # Other content cache for 30 minutes
    }
    
    # Add cache control headers
    set beresp.http.Cache-Control = "public, max-age=" + beresp.ttl;
    
    return (deliver);
}

sub vcl_deliver {
    # Add cache status headers for debugging
    if (obj.hits > 0) {
        set resp.http.X-Varnish-Cache = "HIT";
    } else {
        set resp.http.X-Varnish-Cache = "MISS";
    }
    
    # Add cache hits count
    set resp.http.X-Varnish-Hits = obj.hits;
    
    return (deliver);
}