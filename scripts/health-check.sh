#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Verificando saúde dos serviços...${NC}"
echo ""

# Verificar PostgreSQL
echo -n "PostgreSQL (localhost:5432): "
if pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Online${NC}"
    
    # Verificar se os bancos existem
    echo -n "  Database churchmanager_development: "
    if psql -h localhost -p 5432 -U postgres -d churchmanager_development -c '\q' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Existe${NC}"
    else
        echo -e "${RED}❌ Não encontrado${NC}"
    fi
else
    echo -e "${RED}❌ Offline${NC}"
fi

# Verificar Redis
echo -n "Redis (localhost:6379): "
if redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Online${NC}"
else
    echo -e "${RED}❌ Offline${NC}"
fi

# Verificar Rails
echo -n "Rails Server (localhost:3000): "
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Online${NC}"
else
    echo -e "${YELLOW}⚠️ Offline ou não iniciado${NC}"
fi

# Verificar gems
echo -n "Gems instaladas: "
if bundle check > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Faltando gems${NC}"
    echo "  Execute: bundle install"
fi

# Verificar migrações
echo -n "Migrações do banco: "
if bundle exec rails db:version > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ Pendentes${NC}"
    echo "  Execute: bundle exec rails db:migrate"
fi

echo ""
echo -e "${BLUE}📊 Resumo dos portos:${NC}"
echo "  PostgreSQL: 5432"
echo "  Redis: 6379"
echo "  Rails: 3000"
echo ""
echo -e "${BLUE}🔧 Comandos úteis:${NC}"
echo "  devenv processes up    # Iniciar todos os serviços"
echo "  devenv processes down  # Parar todos os serviços"
echo "  setup                  # Configurar aplicação"
echo "  dev                    # Iniciar desenvolvimento"