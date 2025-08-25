#!/bin/bash

# Basic Local AI - Complete destruction script
# Removes ALL traces

set -e  # Exit on any error

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "💥 Basic Local AI - Complete Destruction Script"
echo "==============================================="
echo "⚠️  WARNING: This will remove EVERYTHING!"
echo "   - All Docker containers and images"
echo "   - All Ollama models and data"
echo "   - All Docker volumes and networks"
echo "   - All project-generated files"
echo ""

# Confirmation prompt
read -p "Are you absolutely sure you want to destroy everything? Type 'DESTROY' to confirm: " confirmation

if [ "$confirmation" != "DESTROY" ]; then
    echo "❌ Destruction cancelled. Nothing was removed."
    exit 0
fi

echo ""
echo "🚀 Starting complete destruction..."

# Function to stop and remove all containers
remove_containers() {
    echo "🐳 Removing all containers..."
    
    # Stop all running containers
    if docker ps -q | grep -q .; then
        echo "   ⏹️  Stopping running containers..."
        docker stop $(docker ps -q) 2>/dev/null || true
    fi
    
    # Remove all containers (including stopped ones)
    if docker ps -aq | grep -q .; then
        echo "   🗑️  Removing all containers..."
        docker rm $(docker ps -aq) 2>/dev/null || true
    fi
    
    echo "✅ All containers removed"
}

# Function to remove all images
remove_images() {
    echo "🖼️  Removing all Docker images..."
    
    # Remove all images
    if docker images -q | grep -q .; then
        echo "   🗑️  Removing all images..."
        docker rmi $(docker images -q) -f 2>/dev/null || true
    fi
    
    echo "✅ All Docker images removed"
}

# Function to remove all volumes
remove_volumes() {
    echo "💾 Removing all Docker volumes..."
    
    # Remove all volumes
    if docker volume ls -q | grep -q .; then
        echo "   🗑️  Removing all volumes..."
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
    fi
    
    echo "✅ All Docker volumes removed"
}

# Function to remove all networks
remove_networks() {
    echo "🌐 Removing all Docker networks..."
    
    # Remove all custom networks (keep default ones)
    if docker network ls --filter "type=custom" -q | grep -q .; then
        echo "   🗑️  Removing custom networks..."
        docker network rm $(docker network ls --filter "type=custom" -q) 2>/dev/null || true
    fi
    
    echo "✅ All custom networks removed"
}

# Function to remove project-specific data
remove_project_data() {
    echo "📁 Removing project-specific data..."
    
    cd "$PROJECT_ROOT"
    
    # Remove Ollama data directory
    echo "   🗑️  Removing Ollama data..."
    if [ -d "$PROJECT_ROOT/ollama_data" ]; then
        rm -rf "$PROJECT_ROOT/ollama_data"
        echo "   ✅ Ollama data directory removed: $PROJECT_ROOT/ollama_data"
    fi
    
    # Remove data directory
    echo "   🗑️  Removing conversation data..."
    if [ -d "$PROJECT_ROOT/data" ]; then
        rm -rf "$PROJECT_ROOT/data"
        echo "   ✅ Conversation data directory removed: $PROJECT_ROOT/data"
    fi
    
    echo "✅ Project-specific data removed"
}

# Function to remove Docker Compose artifacts
remove_compose_artifacts() {
    echo "🔧 Removing Docker Compose artifacts..."
    
    cd "$PROJECT_ROOT"
    
    # Remove any remaining Docker Compose artifacts
    if docker compose ps --services 2>/dev/null | grep -q .; then
        echo "   🗑️  Removing Docker Compose services..."
        docker compose down --volumes --remove-orphans 2>/dev/null || true
    fi
    
    echo "✅ Docker Compose artifacts removed"
}

# Function to clean Docker system
clean_docker_system() {
    echo "🧹 Cleaning Docker system..."
    
    # Prune everything
    echo "   🗑️  Pruning Docker system..."
    docker system prune -a -f --volumes 2>/dev/null || true
    
    echo "✅ Docker system cleaned"
}

# Function to verify destruction
verify_destruction() {
    echo "🔍 Verifying destruction..."
    
    # Check if any containers remain
    if docker ps -aq | grep -q .; then
        echo "   ⚠️  Warning: Some containers still exist"
        docker ps -a
    else
        echo "   ✅ All containers removed"
    fi
    
    # Check if any images remain
    if docker images -q | grep -q .; then
        echo "   ⚠️  Warning: Some images still exist"
        docker images
    else
        echo "   ✅ All images removed"
    fi
    
    # Check if any volumes remain
    if docker volume ls -q | grep -q .; then
        echo "   ⚠️  Warning: Some volumes still exist"
        docker volume ls
    else
        echo "   ✅ All volumes removed"
    fi
    
    # Check if any custom networks remain
    if docker network ls --filter "type=custom" -q | grep -q .; then
        echo "   ⚠️  Warning: Some custom networks still exist"
        docker network ls --filter "type=custom"
    else
        echo "   ✅ All custom networks removed"
    fi
    
    # Check project directory
    cd "$PROJECT_ROOT"
    if [ -d "$PROJECT_ROOT/data" ]; then
        echo "   ⚠️  Warning: Data directory still exists: $PROJECT_ROOT/data"
    else
        echo "   ✅ Data directory removed"
    fi
    
    if [ -d "$PROJECT_ROOT/ollama_data" ]; then
        echo "   ⚠️  Warning: Ollama data directory still exists: $PROJECT_ROOT/ollama_data"
    else
        echo "   ✅ Ollama data directory removed"
    fi
}

# Main destruction sequence
main() {
    echo "💥 Starting complete destruction sequence..."
    echo ""
    
    # 1. Stop and remove containers
    remove_containers
    echo ""
    
    # 2. Remove project-specific data
    remove_project_data
    echo ""
    
    # 3. Remove Docker Compose artifacts
    remove_compose_artifacts
    echo ""
    
    # 4. Remove all images
    remove_images
    echo ""
    
    # 5. Remove all volumes
    remove_volumes
    echo ""
    
    # 6. Remove all networks
    remove_networks
    echo ""
    
    # 7. Clean Docker system
    clean_docker_system
    echo ""
    
    # 8. Verify destruction
    verify_destruction
    echo ""
    
    echo "🎉 DESTRUCTION COMPLETE!"
    echo "================================"
    echo "✅ All traces of Basic Local AI have been removed:"
    echo "   - Docker containers: GONE"
    echo "   - Docker images: GONE"
    echo "   - Docker volumes: GONE"
    echo "   - Docker networks: GONE"
    echo "   - Ollama data: GONE"
    echo "   - Project artifacts: GONE"
    echo ""
    echo "🌍 Your system is now clean of all Basic Local AI traces!"
    echo ""
    echo "💡 To start fresh, run: bash scripts/start.sh"
}

# Run main destruction
main "$@"

