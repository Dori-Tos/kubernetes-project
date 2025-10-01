FROM varnish:7.4

# Copy the VCL configuration
COPY default.vcl /etc/varnish/default.vcl

# Expose Varnish port
EXPOSE 80

# Start Varnish with custom configuration
CMD ["varnishd", "-F", "-f", "/etc/varnish/default.vcl", "-s", "malloc,256m", "-a", "0.0.0.0:80"]