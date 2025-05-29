#!/usr/bin/env python3
"""
MCP SSE Server for Azure Container Apps
Implements Server-Sent Events (SSE) for VS Code compatibility
"""

import asyncio
import json
import os
import subprocess
import logging
from aiohttp import web
from aiohttp_sse import sse_response
import uuid
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get configuration from environment
PORT = int(os.environ.get('PORT', 3000))
API_KEY = os.environ.get('API_KEY', '')

class MCPSSEServer:
    def __init__(self):
        self.app = web.Application()
        self.setup_routes()
        self.active_processes = {}
        
    def setup_routes(self):
        self.app.router.add_get('/health', self.health_check)
        self.app.router.add_post('/mcp/v1/sse', self.handle_sse)
        self.app.router.add_get('/', self.root_handler)
        
    async def root_handler(self, request):
        """Root endpoint for basic info"""
        return web.json_response({
            'name': 'Terraform MCP Server',
            'version': '1.0.0',
            'protocol': 'sse',
            'endpoint': '/mcp/v1/sse'
        })
        
    async def health_check(self, request):
        return web.json_response({'status': 'healthy'})
    
    def check_auth(self, request):
        """Verify API key authentication if configured"""
        if not API_KEY:
            return True  # No auth required if API_KEY not set
            
        auth_header = request.headers.get('Authorization', '')
        if auth_header.startswith('Bearer '):
            token = auth_header[7:]
            return token == API_KEY
        
        # Also check for API key in headers
        return request.headers.get('X-API-Key', '') == API_KEY
    
    async def handle_sse(self, request):
        """Handle SSE requests for MCP communication"""
        if not self.check_auth(request):
            return web.Response(status=401, text='Unauthorized')
        
        logger.info("New SSE connection established")
        
        async with sse_response(request) as resp:
            process_id = str(uuid.uuid4())
            
            # Start the MCP server process
            process = await asyncio.create_subprocess_exec(
                'terraform-mcp-server',
                'stdio',
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            self.active_processes[process_id] = process
            logger.info(f"Started MCP server process {process_id}")
            
            try:
                # Read request body if present
                body = await request.read()
                if body:
                    # Send initial request to MCP server
                    logger.info(f"Sending initial request to MCP: {body[:100]}...")
                    process.stdin.write(body + b'\n')
                    await process.stdin.drain()
                
                # Create tasks for handling process output
                stdout_task = asyncio.create_task(
                    self.forward_process_output(process, resp, process_id)
                )
                
                # Wait for the task to complete
                await stdout_task
                
            except asyncio.CancelledError:
                logger.info(f"SSE connection cancelled for process {process_id}")
            except Exception as e:
                logger.error(f"Error in SSE handler: {e}")
                await resp.send(json.dumps({
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": f"Internal error: {str(e)}"
                    }
                }))
            finally:
                # Clean up
                if process_id in self.active_processes:
                    process.terminate()
                    await process.wait()
                    del self.active_processes[process_id]
                    logger.info(f"Cleaned up process {process_id}")
                
        return resp
    
    async def forward_process_output(self, process, resp, process_id):
        """Forward MCP process output to SSE response"""
        try:
            while True:
                # Read line from process stdout
                line = await process.stdout.readline()
                if not line:
                    logger.info(f"Process {process_id} stdout closed")
                    break
                
                # Decode and send via SSE
                data = line.decode().strip()
                if data:
                    logger.debug(f"Sending SSE data: {data[:100]}...")
                    await resp.send(data)
                    
        except Exception as e:
            logger.error(f"Error forwarding output from process {process_id}: {e}")
    
    def run(self):
        logger.info(f"Starting MCP SSE server on port {PORT}")
        if API_KEY:
            logger.info("API key authentication enabled")
        else:
            logger.info("Warning: Running without API key authentication")
            
        web.run_app(self.app, host='0.0.0.0', port=PORT)

if __name__ == '__main__':
    server = MCPSSEServer()
    server.run()