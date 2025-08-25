# Basic Local AI

A minimal, containerized AI service that provides basic text generation capabilities using Ollama and local models, with conversation storage and a web interface.

## Features

- 🤖 **Local AI Models**: Uses Ollama to run AI models locally
- 🐳 **Docker Containerized**: Easy setup and deployment
- 📱 **Simple API**: RESTful API for text generation
- 🌐 **Web Interface**: User-friendly browser interface
- 💾 **Conversation Storage**: Automatically saves all prompts and responses
- 🚀 **Auto-setup**: Automated installation and model download
- 🧪 **Built-in Testing**: Automatic testing with basic prompts

## Quick Start

### Prerequisites

- Docker Desktop running
- At least 4GB of free disk space for models
- Internet connection for initial model download

### Installation

1. **Clone or download this folder**
2. **Run the installation script:**
   ```bash
   bash scripts/install.sh
   ```
   This will:
   - Pull Docker images
   - Start Ollama service
   - Download a default AI model (~2-4GB)
   - Create data directories for storage

### Starting the Service

```bash
bash scripts/start.sh
```

This will:
- Start all services
- Verify everything is working
- Run a basic test with the prompt "Hello, how are you?"
- Test conversation storage
- Show service status

### Using the Service

#### Web Interface (Recommended)
Open your browser and go to `http://localhost:5000` for an interactive interface that includes:
- Text generation form
- Real-time AI responses
- Conversation history viewer
- Easy-to-use interface

#### API Endpoints

Once running, the API is available at `http://localhost:5000`:

- **Web Interface**: `GET /` - Interactive web interface
- **Health Check**: `GET /health` - Service status and conversation count
- **Generate Text**: `POST /generate` - Generate text from prompt
- **View Conversations**: `GET /conversations` - Get conversation history
- **Get Specific Conversation**: `GET /conversations/{id}` - Get conversation by ID

**Example API Usage:**
```bash
# Generate text
curl -X POST http://localhost:5000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a short poem about coding"}'

# View conversation history
curl http://localhost:5000/conversations

# Get specific conversation
curl http://localhost:5000/conversations/1
```

## Data Storage

The service automatically stores all conversations in:
- **Conversations**: `./data/conversations.json`
- **AI Models**: `./ollama_data/`

Each conversation includes:
- Unique ID
- Timestamp
- Original prompt
- AI response
- Model used
- Response length

The system keeps the last 100 conversations to prevent storage bloat.

## Scripts

- **`scripts/install.sh`** - Initial setup and model installation
- **`scripts/start.sh`** - Start services and run comprehensive tests
- **`scripts/stop.sh`** - Gracefully stop services (preserves data)
- **`scripts/destroy.sh`** - Remove everything (use with caution!)

## Configuration

### Environment Variables

- `MODEL_NAME`: AI model to use (default: `llama3.2:3b`)
- `OLLAMA_HOST`: Ollama service URL (default: `http://ollama:11434`)

### Supported Models

The service automatically tries these models in order:
1. `llama3.2:3b` (default)
2. `llama3.2:1b`
3. `llama3.1:3b`
4. `llama3.1:1b`

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser  │    │   Basic AI App  │    │     Ollama      │
│   (Port 5000)  │◄──►│   (Flask API)   │◄──►│   (AI Models)   │
│                 │    │   + Storage     │    │   (Port 11434)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Data Storage  │
                       │  (JSON files)  │
                       └─────────────────┘
```

## Troubleshooting

### Common Issues

1. **Docker not running**: Start Docker Desktop first
2. **Port conflicts**: Ensure ports 5000 and 11434 are free
3. **Model download fails**: Check internet connection and try alternative models
4. **API not responding**: Wait for services to become healthy (check logs)
5. **Storage issues**: Ensure `./data` directory has write permissions

### Logs

- **App container**: `docker logs basic-ai-app`
- **Ollama container**: `docker logs basic-ollama`

### Reset Everything

If you need to start completely fresh:

```bash
bash scripts/destroy.sh
bash scripts/install.sh
bash scripts/start.sh
```

## What's Different from the Full Version

This is a simplified version that provides:
- ✅ Basic text generation API
- ✅ **NEW: Web interface for easy interaction**
- ✅ **NEW: Automatic conversation storage**
- ✅ **NEW: Conversation history API**
- ✅ Automatic model installation
- ✅ Health checks and testing
- ❌ No complex content generation
- ❌ No scheduling or advanced features
- ❌ No content templates or pipelines

Perfect for learning, testing, or as a foundation for building more complex AI services with conversation memory.
