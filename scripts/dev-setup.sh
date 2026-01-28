#!/bin/bash

set -e

echo "🚀 Configurando ambiente de desenvolvimento..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Verificar se estamos no devenv
if [ -z "$DEVENV_ROOT" ]; then
    error "Este script deve ser executado dentro do ambiente devenv"
fi

# Instalar dependências Ruby
log "Instalando gems..."
if [ ! -f "vendor/bundle/config" ]; then
    bundle config set --local path 'vendor/bundle'
fi
bundle install || error "Falha ao instalar gems"
success "Gems instaladas"

# Aguardar PostgreSQL
log "Aguardando PostgreSQL estar disponível..."
timeout=30
while ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; do
    sleep 1
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        error "PostgreSQL não iniciou em tempo hábil"
    fi
done
success "PostgreSQL disponível"

# Aguardar Redis
log "Aguardando Redis estar disponível..."
timeout=30
while ! redis-cli ping > /dev/null 2>&1; do
    sleep 1
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        error "Redis não iniciou em tempo hábil"
    fi
done
success "Redis disponível"

# Configurar banco de dados
log "Configurando banco de dados..."
if ! bundle exec rails db:version > /dev/null 2>&1; then
    log "Criando banco de dados..."
    bundle exec rails db:create || error "Falha ao criar banco"
    
    log "Executando migrações..."
    bundle exec rails db:migrate || error "Falha ao executar migrações"
    
    log "Executando seeds..."
    bundle exec rails db:seed || error "Falha ao executar seeds"
else
    log "Executando migrações pendentes..."
    bundle exec rails db:migrate || error "Falha ao executar migrações"
fi
success "Banco de dados configurado"

# Instalar dependências JavaScript
if [ -f "package.json" ]; then
    log "Instalando dependências JavaScript..."
    yarn install || npm install || warning "Falha ao instalar dependências JavaScript"
fi

# Precompilar assets para desenvolvimento
log "Preparando assets..."
bundle exec rails assets:precompile || warning "Falha ao precompilar assets"

success "🎉 Ambiente configurado com sucesso!"
echo ""
echo "Para iniciar a aplicação:"
echo "  devenv processes up    # Inicia todos os serviços"
echo "  ou"
echo "  overmind start -f Procfile.dev    # Usando overmind"
echo ""
echo "Acesse: http://localhost:3000"