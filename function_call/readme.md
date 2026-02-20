# function_call — Shared Utilities

This directory contains shared Python modules used by both the backend API server (`backend_server.py`) and the voice agent runtime (`voxie-test/`).

## Modules

### `supabase_client.py`

Supabase database client singleton. Reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from environment variables and exposes a shared client instance for all database operations.

### `agent_persistence.py`

CRUD operations for voice agent configurations — creating, reading, updating, and deleting agent records in the `agents` Supabase table.

### `ragie_db_tool.py`

Integration with [Ragie](https://ragie.ai) for RAG (Retrieval-Augmented Generation). Allows voice agents to search and retrieve answers from uploaded knowledge base documents.

### `ragie_voice_agent.py`

Voice agent implementation that uses Ragie RAG tools to answer questions from a knowledge base during voice conversations.

### `voice_agent_function.py`

Function call tools for voice agents — includes natural language query processing, product search, and structured response generation.

### `voice_agent_hybrid.py`

Hybrid voice agent that combines multiple capabilities (RAG, function calls, general conversation).

### `webhook_server.py`

Flask-based webhook server for handling external integrations and callbacks.

## Usage

These modules are imported by the backend and agent code via `sys.path`:

```python
import sys
sys.path.append('./function_call')
from supabase_client import supabase_client
```
