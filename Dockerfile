FROM hashicorp/terraform-mcp-server:latest

# Install nginx, supervisord, and envsubst (gettext)
USER root
RUN apk add --no-cache nginx supervisor gettext

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf.template
COPY supervisord.conf /etc/supervisord.conf

# Create nginx directories and set permissions
RUN mkdir -p /var/lib/nginx/tmp /var/log/nginx /run/nginx && \
    chown -R nginx:nginx /var/lib/nginx /var/log/nginx /run/nginx

# Create startup script that substitutes API_KEY into nginx config
RUN printf '#!/bin/sh\nenvsubst "\${API_KEY}" < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf\nexec /usr/bin/supervisord -c /etc/supervisord.conf\n' > /start.sh && \
    chmod +x /start.sh

# Expose port 8080 (nginx) - MCP server runs internally on 9000
EXPOSE 8080

# Health check via nginx
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

CMD ["/start.sh"]
