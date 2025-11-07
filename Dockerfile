FROM hashicorp/terraform-mcp-server:latest

# Install Python and dependencies for SSE wrapper
RUN apk add --no-cache python3 py3-pip && \
    pip3 install --break-system-packages aiohttp aiohttp-sse

# Create non-root user
RUN adduser -D -u 1000 mcp && \
    chown -R mcp:mcp /usr/local/bin

# Copy wrapper script
COPY --chown=mcp:mcp mcp-sse-server.py /usr/local/bin/
RUN chmod +x /usr/local/bin/mcp-sse-server.py

# Switch to non-root user
USER mcp

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:3000/health')" || exit 1

# Run the SSE server
CMD ["python3", "/usr/local/bin/mcp-sse-server.py"]