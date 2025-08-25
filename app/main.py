import os
import json
import time
from datetime import datetime
from flask import Flask, jsonify, request, render_template_string
import requests

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
MODEL_NAME = os.getenv("MODEL_NAME", "llama3.2:3b")
PORT = int(os.environ.get("PORT", 5000))

app = Flask(__name__)

# Storage for conversations
CONVERSATIONS_FILE = "/data/conversations.json"
DATA_DIR = "/data"

# Ensure data directory exists
os.makedirs(DATA_DIR, exist_ok=True)

def load_conversations():
    """Load conversations from file"""
    try:
        if os.path.exists(CONVERSATIONS_FILE):
            with open(CONVERSATIONS_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
    except Exception as e:
        print(f"⚠️  Error loading conversations: {e}")
    return []

def save_conversations(conversations):
    """Save conversations to file"""
    try:
        with open(CONVERSATIONS_FILE, 'w', encoding='utf-8') as f:
            json.dump(conversations, f, indent=2, ensure_ascii=False)
        return True
    except Exception as e:
        print(f"❌ Error saving conversations: {e}")
        return False

def add_conversation(prompt, response, model_name):
    """Add a new conversation to storage"""
    conversations = load_conversations()
    
    conversation = {
        "id": len(conversations) + 1,
        "timestamp": datetime.now().isoformat(),
        "prompt": prompt,
        "response": response,
        "model": model_name,
        "response_length": len(response)
    }
    
    conversations.append(conversation)
    
    # Keep only last 100 conversations to prevent file from growing too large
    if len(conversations) > 100:
        conversations = conversations[-100:]
        # Reassign IDs
        for i, conv in enumerate(conversations):
            conv["id"] = i + 1
    
    if save_conversations(conversations):
        print(f"💾 Saved conversation #{conversation['id']}")
        return conversation
    else:
        print("❌ Failed to save conversation")
        return None

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    conversations = load_conversations()
    return jsonify({
        "status": "healthy",
        "service": "Basic Local AI",
        "model": MODEL_NAME,
        "total_conversations": len(conversations),
        "storage_file": CONVERSATIONS_FILE
    })

@app.route('/generate', methods=['POST'])
def generate_text():
    """Generate text from prompt"""
    try:
        data = request.get_json() or {}
        prompt = data.get('prompt', 'Hello, how are you?')
        
        print(f"🤖 Generating text with prompt: {prompt[:50]}...")
        
        # Call Ollama API
        url = f"{OLLAMA_HOST}/api/generate"
        payload = {
            "model": MODEL_NAME,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
            },
        }
        
        response = requests.post(url, json=payload, timeout=180)
        
        if response.status_code == 200:
            result = response.json()
            generated_text = result.get("response", "").strip()
            
            print(f"✅ Text generated successfully ({len(generated_text)} chars)")
            
            # Store the conversation
            conversation = add_conversation(prompt, generated_text, MODEL_NAME)
            
            return jsonify({
                "status": "success",
                "generated_text": generated_text,
                "model": MODEL_NAME,
                "conversation_id": conversation["id"] if conversation else None
            })
        else:
            return jsonify({
                "status": "error",
                "message": f"Ollama API error: {response.status_code}"
            }), 500
            
    except Exception as e:
        print(f"❌ Error generating text: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/generate', methods=['GET'])
def generate_info():
    """Show generation endpoint info"""
    return jsonify({
        "status": "info",
        "message": "Use POST /generate with JSON body: {\"prompt\": \"your text here\"}",
        "endpoints": {
            "POST /generate": "Generate text from prompt",
            "GET /generate": "This help message",
            "GET /health": "Health check",
            "GET /conversations": "View conversation history",
            "GET /": "Web interface"
        }
    })

@app.route('/conversations', methods=['GET'])
def get_conversations():
    """Get conversation history"""
    conversations = load_conversations()
    
    # Support filtering and pagination
    limit = request.args.get('limit', type=int, default=20)
    offset = request.args.get('offset', type=int, default=0)
    
    # Apply pagination
    paginated_conversations = conversations[offset:offset + limit]
    
    return jsonify({
        "status": "success",
        "total": len(conversations),
        "limit": limit,
        "offset": offset,
        "conversations": paginated_conversations
    })

@app.route('/conversations/<int:conversation_id>', methods=['GET'])
def get_conversation(conversation_id):
    """Get a specific conversation by ID"""
    conversations = load_conversations()
    
    for conv in conversations:
        if conv["id"] == conversation_id:
            return jsonify({
                "status": "success",
                "conversation": conv
            })
    
    return jsonify({
        "status": "error",
        "message": f"Conversation #{conversation_id} not found"
    }), 404

@app.route('/', methods=['GET'])
def web_interface():
    """Basic web interface for the AI service"""
    conversations = load_conversations()
    
    html_template = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Basic Local AI</title>
        <meta charset="utf-8">
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
            .container { max-width: 1200px; margin: 0 auto; }
            .header { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .input-section { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .conversations-section { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            input[type="text"] { width: 70%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; margin-right: 10px; }
            button { padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
            button:hover { background: #0056b3; }
            .conversation { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 4px; background: #f9f9f9; }
            .prompt { background: #e3f2fd; padding: 10px; border-radius: 4px; margin-bottom: 10px; }
            .response { background: #f1f8e9; padding: 10px; border-radius: 4px; }
            .metadata { font-size: 12px; color: #666; margin-top: 10px; }
            .loading { display: none; color: #666; }
            .error { color: #d32f2f; background: #ffebee; padding: 10px; border-radius: 4px; margin: 10px 0; }
            .success { color: #388e3c; background: #e8f5e8; padding: 10px; border-radius: 4px; margin: 10px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🤖 Basic Local AI</h1>
                <p>Local AI text generation service using Ollama</p>
                <p><strong>Model:</strong> {{ model_name }} | <strong>Total Conversations:</strong> {{ total_conversations }}</p>
            </div>
            
            <div class="input-section">
                <h3>Generate Text</h3>
                <input type="text" id="promptInput" placeholder="Enter your prompt here..." value="Hello, how are you?">
                <button onclick="generateText()">Generate</button>
                <div class="loading" id="loading">Generating text...</div>
                <div id="result"></div>
            </div>
            
            <div class="conversations-section">
                <h3>Recent Conversations</h3>
                {% if conversations %}
                    {% for conv in conversations[-10:]|reverse %}
                    <div class="conversation">
                        <div class="prompt"><strong>Prompt:</strong> {{ conv.prompt }}</div>
                        <div class="response"><strong>Response:</strong> {{ conv.response }}</div>
                        <div class="metadata">
                            ID: #{{ conv.id }} | Model: {{ conv.model }} | 
                            Length: {{ conv.response_length }} chars | 
                            Time: {{ conv.timestamp[:19].replace('T', ' ') }}
                        </div>
                    </div>
                    {% endfor %}
                {% else %}
                    <p>No conversations yet. Generate some text to get started!</p>
                {% endif %}
            </div>
        </div>
        
        <script>
            async function generateText() {
                const prompt = document.getElementById('promptInput').value;
                const loading = document.getElementById('loading');
                const result = document.getElementById('result');
                
                if (!prompt.trim()) {
                    result.innerHTML = '<div class="error">Please enter a prompt</div>';
                    return;
                }
                
                loading.style.display = 'block';
                result.innerHTML = '';
                
                try {
                    const response = await fetch('/generate', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ prompt: prompt })
                    });
                    
                    const data = await response.json();
                    
                    if (data.status === 'success') {
                        result.innerHTML = `
                            <div class="success">
                                <strong>Generated Text:</strong><br>
                                ${data.generated_text.replace(/\\n/g, '<br>')}<br><br>
                                <small>Conversation ID: #${data.conversation_id}</small>
                            </div>
                        `;
                        // Reload page to show new conversation
                        setTimeout(() => location.reload(), 2000);
                    } else {
                        result.innerHTML = `<div class="error">Error: ${data.message}</div>`;
                    }
                } catch (error) {
                    result.innerHTML = `<div class="error">Error: ${error.message}</div>`;
                } finally {
                    loading.style.display = 'none';
                }
            }
            
            // Allow Enter key to submit
            document.getElementById('promptInput').addEventListener('keypress', function(e) {
                if (e.key === 'Enter') {
                    generateText();
                }
            });
        </script>
    </body>
    </html>
    """
    
    return render_template_string(html_template, 
                                model_name=MODEL_NAME, 
                                total_conversations=len(conversations),
                                conversations=conversations)

if __name__ == "__main__":
    print("🚀 Starting Basic Local AI...")
    print(f"🤖 Model: {MODEL_NAME}")
    print(f"🌐 API available at: http://localhost:{PORT}")
    print(f"💾 Storage: {CONVERSATIONS_FILE}")
    print("📱 Endpoints:")
    print("   - GET / - Web interface")
    print("   - POST /generate - Generate text from prompt")
    print("   - GET /conversations - View conversation history")
    print("   - GET /health - Health check")
    print()
    
    app.run(host='0.0.0.0', port=PORT, debug=False)
