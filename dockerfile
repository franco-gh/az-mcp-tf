FROM hashicorp/terraform-mcp-server:latest

# Install Python and dependencies for SSE wrapper
RUN apk add --no-cache python3 py3-pip
RUN pip3 install --break-system-packages aiohttp aiohttp-sse

# Copy wrapper script
COPY mcp-sse-server.py /usr/local/bin/
RUN chmod +x /usr/local/bin/mcp-sse-server.py

# Expose port
EXPOSE 3000

# Run the SSE server
CMD ["python3", "/usr/local/bin/mcp-sse-server.py"]