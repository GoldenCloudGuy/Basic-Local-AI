#!/bin/bash

# Basic Local AI - Automated startup script
# Handles setup, model installation, and basic testing

set -e  # Exit on any error

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Basic Local AI Startup Script"
echo "================================"

# Pick a free port (5000-5099) similar to Power-Point-Basics, with robust detection
port_in_use() {
    local p="$1"
    if command -v ss >/dev/null 2>&1; then
        # Match end of address with :port or .port (covers IPv4/IPv6/abstract)
        if ss -ltn 2>/dev/null | awk '{print $4}' | grep -E -q "(:|\.)${p}$"; then
            return 0
        fi
    fi
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -E -q "[:\.]${p}(\\s|$)"; then
            return 0
        fi
    fi
    if command -v lsof >/dev/null 2>&1; then
        if lsof -iTCP:${p} -sTCP:LISTEN -n -P 2>/dev/null | grep -q .; then
            return 0
        fi
    fi
    return 1
}

pick_port() {
    for p in $(seq 5000 5099); do
        if ! port_in_use "$p"; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

# Function to check if Ollama is running and healthy
check_ollama() {
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "basic-ollama.*healthy"; then
        return 0
    else
        return 1
    fi
}

# Function to check if app container is running and API is responding
check_app_api() {
    # Check if container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "basic-ai-app"; then
        return 1
    fi
    
    # Check if API is responding
    for attempt in {1..5}; do
        if curl -s -f http://localhost:${PORT:-5000}/health >/dev/null 2>&1; then
            return 0
        fi
        echo "   ⏳ API not ready yet, attempt $attempt/5..."
        sleep 3
    done
    return 1
}

# Function to check if containers need rebuilding
check_containers_need_rebuild() {
    echo "🔧 Checking if containers need rebuilding..."
    
    # Check if we need to rebuild (if requirements.txt changed or code changed)
    if [ ! -f "$PROJECT_ROOT/.last_build" ] || \
       [ "$(stat -c %Y "$PROJECT_ROOT/app/requirements.txt" 2>/dev/null || echo 0)" -gt "$(cat "$PROJECT_ROOT/.last_build" 2>/dev/null || echo 0)" ] || \
       [ "$(stat -c %Y "$PROJECT_ROOT/app/main.py" 2>/dev/null || echo 0)" -gt "$(cat "$PROJECT_ROOT/.last_build" 2>/dev/null || echo 0)" ] || \
       [ "$(stat -c %Y "$PROJECT_ROOT/docker-compose.yml" 2>/dev/null || echo 0)" -gt "$(cat "$PROJECT_ROOT/.last_build" 2>/dev/null || echo 0)" ]; then
        
        echo "📦 Code changes detected, rebuilding app container..."
        cd "$PROJECT_ROOT"
        
        # Stop existing services if running
        if docker compose ps --services 2>/dev/null | grep -q "app\|ollama"; then
            echo "   ⏹️  Stopping existing services..."
            docker compose down
        fi
        
        # Rebuild the app container
        echo "   🔨 Building app container..."
        docker compose build app
        
        # Mark build time
        date +%s > "$PROJECT_ROOT/.last_build"
        echo "✅ App container rebuilt successfully"
        return 0  # Needs rebuild
    else
        echo "✅ App container is up to date"
        return 1  # No rebuild needed
    fi
}

# Function to setup data directories with proper paths
setup_data_directories() {
    echo "📁 Setting up data directories..."
    
    # Get absolute paths that Docker can use
    OLLAMA_DATA_DIR="$PROJECT_ROOT/ollama_data"
    DATA_DIR="$PROJECT_ROOT/data"
    
    # Robustly ensure directories exist (handle conflicting files)
    ensure_dir() {
        local d="$1"
        if [ -d "$d" ]; then
            return 0
        fi
        if [ -e "$d" ] && [ ! -d "$d" ]; then
            local ts=$(date +%s)
            echo "   Detected non-directory at '$d'"
            if mv "$d" "${d}.bak-${ts}" 2>/dev/null; then
                echo "   Backed up to ${d}.bak-${ts}"
            else
                echo "   Backup failed, force removing '$d'"
                chmod -R u+w "$d" 2>/dev/null || true
                rm -rf "$d" 2>/dev/null || true
                if [ -e "$d" ]; then
                    echo "   Could not remove conflicting path '$d'"
                    return 1
                fi
            fi
        fi
        mkdir -p "$d" 2>/dev/null || {
            echo "   Failed to create directory '$d'"
            return 1
        }
    }

    if ! ensure_dir "$OLLAMA_DATA_DIR"; then
        echo "   Could not use '$OLLAMA_DATA_DIR', picking a unique working directory..."
        for attempt in $(seq 1 20); do
            ts=$(date +%s)
            candidate="$PROJECT_ROOT/ollama_data_working_${ts}_${attempt}"
            if mkdir -p "$candidate" 2>/dev/null; then
                OLLAMA_DATA_DIR="$candidate"
                echo "   Using working directory for Ollama: $OLLAMA_DATA_DIR"
                break
            fi
            sleep 1
        done
    fi

    if ! ensure_dir "$DATA_DIR"; then
        echo "   Could not use '$DATA_DIR', picking a unique working directory..."
        for attempt in $(seq 1 20); do
            ts=$(date +%s)
            candidate="$PROJECT_ROOT/data_working_${ts}_${attempt}"
            if mkdir -p "$candidate" 2>/dev/null; then
                DATA_DIR="$candidate"
                echo "   Using working directory for data: $DATA_DIR"
                break
            fi
            sleep 1
        done
    fi

    # Normalize directories for Compose binding (ensure bind path, not named volume)
    NORM_OLLAMA_DIR="$OLLAMA_DATA_DIR"
    NORM_DATA_DIR="$DATA_DIR"
    case "$NORM_OLLAMA_DIR" in
      /*|./*|../*|~/*|[A-Za-z]:*|\\*) ;;
      *) NORM_OLLAMA_DIR="./${NORM_OLLAMA_DIR#$PROJECT_ROOT/}" ;;
    esac
    case "$NORM_DATA_DIR" in
      /*|./*|../*|~/*|[A-Za-z]:*|\\*) ;;
      *) NORM_DATA_DIR="./${NORM_DATA_DIR#$PROJECT_ROOT/}" ;;
    esac

    export OLLAMA_DIR="$NORM_OLLAMA_DIR"
    export DATA_DIR="$NORM_DATA_DIR"
    
    # Ensure directories have proper permissions
    chmod 755 "$OLLAMA_DATA_DIR" 2>/dev/null || true
    chmod 755 "$DATA_DIR" 2>/dev/null || true
    
    echo "✅ Data directories ready:"
    echo "   - Ollama data: $OLLAMA_DATA_DIR (bind: $OLLAMA_DIR)"
    echo "   - Conversations: $DATA_DIR (bind: $DATA_DIR)"
    
    # Show current directory structure
    echo "📂 Current directory structure:"
    ls -la "$PROJECT_ROOT" | grep -E "(data|ollama_data)" || echo "   (directories may be empty)"
    
    # Verify Docker can access these directories
    echo "🔍 Verifying Docker access to directories..."
    if [ -w "$OLLAMA_DATA_DIR" ] && [ -w "$DATA_DIR" ]; then
        echo "✅ Directories are writable by Docker"
    else
        echo "⚠️  Warning: Directories may not be writable by Docker"
        echo "   💡 This could cause storage issues"
    fi
}

# Function to start services
start_services() {
    echo "🚀 Starting services..."
    echo "   Using model: ${MODEL_NAME:-llama3.2:3b}"
    
    # Setup data directories before starting Docker
    setup_data_directories
    
    # Export PWD for docker-compose to use
    export PWD="$PROJECT_ROOT"
    # Ensure PORT and bind dirs are exported for compose and write .env for stability
    export PORT="${PORT:-5000}"
    {
        echo "PORT=$PORT"
        echo "DATA_DIR=${DATA_DIR}"
        echo "OLLAMA_DIR=${OLLAMA_DIR}"
        echo "MODEL_NAME=${MODEL_NAME:-llama3.2:3b}"
    } > "$PROJECT_ROOT/.env"
    echo "   📍 Using project directory: $PWD"
    echo "   🌐 Using port: $PORT"
    
    docker compose up -d
    
    echo "⏳ Waiting for services to become ready..."
    
    # Wait for Ollama to be healthy
    echo "   🐳 Waiting for Ollama to become healthy..."
    timeout=300  # 5 minutes
    while ! check_ollama && [ $timeout -gt 0 ]; do
        echo "   ⏳ Ollama not ready yet, waiting... ($timeout seconds left)"
        sleep 10
        timeout=$((timeout - 10))
    done
    
    if ! check_ollama; then
        echo "❌ Timeout waiting for Ollama to become healthy"
        exit 1
    fi
    echo "✅ Ollama is healthy"
    
    # Wait for app API to be responding
    echo "   🌐 Waiting for app API to become ready..."
    timeout=120  # 2 minutes
    while ! check_app_api && [ $timeout -gt 0 ]; do
        echo "   ⏳ API not ready yet, waiting... ($timeout seconds left)"
        sleep 5
        timeout=$((timeout - 5))
    done
    
    if ! check_app_api; then
        echo "❌ Timeout waiting for app API to become ready"
        exit 1
    fi
    echo "✅ App API is responding"
}

# Function to run basic test
run_basic_test() {
    echo "🧪 Running basic AI test..."
    echo "================================"
    
    # Test health endpoint
    echo "🏥 Testing health endpoint..."
    if curl -s -f http://localhost:${PORT:-5000}/health >/dev/null 2>&1; then
        echo "✅ Health endpoint working"
    else
        echo "❌ Health endpoint failed"
        return 1
    fi
    
    # Test basic text generation
    echo "🚀 Testing basic text generation..."
    echo "   📝 Sending simple prompt: 'Hello, how are you?'"
    
    response=$(curl -s -X POST http://localhost:${PORT:-5000}/generate \
        -H "Content-Type: application/json" \
        -d '{"prompt": "Hello, how are you?"}')
    
    if echo "$response" | grep -q "success"; then
        echo "✅ Basic text generation working"
        
        # Extract and show the generated text
        generated_text=$(echo "$response" | grep -o '"generated_text":"[^"]*"' | cut -d'"' -f4)
        conversation_id=$(echo "$response" | grep -o '"conversation_id":[0-9]*' | cut -d':' -f2)
        
        if [ -n "$generated_text" ]; then
            echo "   📝 Generated text: ${generated_text:0:100}..."
        fi
        
        if [ -n "$conversation_id" ]; then
            echo "   💾 Conversation saved with ID: #$conversation_id"
        fi
    else
        echo "❌ Basic text generation failed"
        echo "   Response: $response"
        return 1
    fi
    
    # Test conversation storage
    echo "💾 Testing conversation storage..."
    if curl -s -f http://localhost:${PORT:-5000}/conversations >/dev/null 2>&1; then
        echo "✅ Conversation storage working"
        
        # Check if conversation was actually saved
        conversations_response=$(curl -s http://localhost:${PORT:-5000}/conversations)
        if echo "$conversations_response" | grep -q "Hello, how are you?"; then
            echo "✅ Conversation successfully stored and retrievable"
        else
            echo "⚠️  Conversation may not have been stored properly"
        fi
    else
        echo "❌ Conversation storage failed"
        return 1
    fi
    
    # Check if data file was actually created locally
    echo "📁 Checking local data storage..."
    if [ -f "$PROJECT_ROOT/data/conversations.json" ]; then
        file_size=$(stat -c %s "$PROJECT_ROOT/data/conversations.json" 2>/dev/null || echo "unknown")
        echo "✅ Local data file created: $PROJECT_ROOT/data/conversations.json ($file_size bytes)"
        
        # Show first few lines of the file
        echo "   📄 File contents preview:"
        head -5 "$PROJECT_ROOT/data/conversations.json" | sed 's/^/      /'
    else
        echo "❌ Local data file not found: $PROJECT_ROOT/data/conversations.json"
        echo "   💡 This might be a Docker volume mounting issue"
        echo "   🔍 Checking Docker volume mounts..."
        docker inspect basic-ai-app | grep -A 10 "Mounts" || echo "   Could not inspect container mounts"
    fi
    
    echo "✅ All basic tests passed!"
    return 0
}

# Function to show status
show_status() {
    echo ""
    echo "🎉 Basic Local AI is now running successfully!"
    echo "================================"
    echo "📱 API Endpoints:"
    echo "   - Web Interface: http://localhost:${PORT:-5000}"
    echo "   - Health Check: http://localhost:${PORT:-5000}/health"
    echo "   - Generate Text: http://localhost:${PORT:-5000}/generate"
    echo "   - Conversations: http://localhost:${PORT:-5000}/conversations"
    echo ""
    echo "🌐 Web Interface Features:"
    echo "   - Interactive text generation form"
    echo "   - View recent conversation history"
    echo "   - Real-time AI responses"
    echo ""
    echo "🐳 Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "💾 Data Storage:"
    echo "   - Conversations: $PROJECT_ROOT/data/conversations.json"
    echo "   - Ollama models: $PROJECT_ROOT/ollama_data/"
    echo ""
    echo "📊 Usage:"
    echo "   - Open http://localhost:${PORT:-5000} in your browser"
    echo "   - Use the web interface for easy interaction"
    echo "   - Check logs: docker logs basic-ai-app"
    echo "   - Stop services: bash scripts/stop.sh"
    echo ""
}

# Main execution
main() {
    cd "$PROJECT_ROOT"
    
    # Resolve PORT: env > .env > pick free
    if [ -z "${PORT:-}" ] && [ -f .env ]; then
        ENV_PORT=$(grep '^PORT=' .env 2>/dev/null | head -n1 | cut -d'=' -f2)
        if [ -n "$ENV_PORT" ]; then
            export PORT="$ENV_PORT"
            echo "   Using existing port from .env: $PORT"
        fi
    fi
    if [ -z "${PORT:-}" ]; then
        PORT=$(pick_port) || PORT=5000
        export PORT
        echo "   Using dynamic port: $PORT"
    else
        echo "   Using pre-set PORT: $PORT"
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker Desktop first."
        exit 1
    fi
    
    # Check if we need to rebuild containers first
    if check_containers_need_rebuild; then
        echo "🔄 Containers were rebuilt, continuing with fresh start..."
    fi
    
    # Always ensure we have a fresh, working state
    echo "🔍 Checking current service status..."
    
    # Check if services are running but may not be working properly
    if check_ollama && check_app_api; then
        echo "✅ Services appear to be running, but let's verify they're working properly..."
        
        # Run a quick health check to make sure everything is actually functional
        if curl -s -f http://localhost:${PORT:-5000}/health >/dev/null 2>&1; then
            echo "✅ All services are running and healthy"
            show_status
            return
        else
            echo "⚠️  Services are running but API is not responding properly"
            echo "🔄 Restarting services to ensure proper functionality..."
        fi
    else
        echo "🔄 Services are not running or not healthy, starting fresh..."
    fi
    
    # Stop any existing services to ensure clean state
    echo "🛑 Stopping any existing services..."
    docker compose down 2>/dev/null || true
    
    # Wait a moment for services to fully stop
    sleep 3
    
    # Start services fresh
    start_services
    
    # Check if the required model is installed
    echo "📦 Checking if required model is installed..."
    MODEL_NAME=${MODEL_NAME:-llama3.2:3b}
    
    if ! docker exec basic-ollama ollama list | grep -q "$MODEL_NAME"; then
        echo "❌ Model '$MODEL_NAME' not found. Installing it now..."
        echo "   📥 This may take 5-15 minutes for the first download..."
        echo "   💾 Model size: ~2-4 GB (depending on model)"
        
        # Pull the model
        if docker exec basic-ollama ollama pull "$MODEL_NAME"; then
            echo "✅ Model '$MODEL_NAME' installed successfully"
        else
            echo "❌ Failed to install model '$MODEL_NAME'"
            echo "   Trying alternative model names..."
            
            # Try alternative model names
            ALTERNATIVE_MODELS=("llama3.2:1b" "llama3.1:3b" "llama3.1:1b")
            MODEL_INSTALLED=false
            
            for alt_model in "${ALTERNATIVE_MODELS[@]}"; do
                echo "   🔄 Trying alternative model: $alt_model"
                if docker exec basic-ollama ollama pull "$alt_model"; then
                    echo "✅ Alternative model '$alt_model' installed successfully"
                    export MODEL_NAME="$alt_model"
                    MODEL_INSTALLED=true
                    break
                fi
            done
            
            if [ "$MODEL_INSTALLED" = false ]; then
                echo "❌ Failed to install any compatible model"
                echo "   Please check your internet connection and try again"
                exit 1
            fi
        fi
    else
        echo "✅ Model '$MODEL_NAME' is already installed"
    fi
    
    # Run basic test
    if run_basic_test; then
        show_status
    else
        echo "❌ Basic test failed"
        echo "💡 Check logs: docker logs basic-ai-app"
        echo "🔄 Attempting to restart services and try again..."
        
        # Try one more restart
        docker compose down
        sleep 3
        start_services
        
        if run_basic_test; then
            show_status
        else
            echo "❌ Services still not working after restart"
            echo "💡 Check logs: docker logs basic-ai-app"
            exit 1
        fi
    fi
}

# Run main function
main "$@"

