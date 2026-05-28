{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";
  env.CHURCHMANAGER_DATABASE_PASSWORD = "a4qpdvb7";
  env.RAILS_ENV = "development";
  env.REDIS_URL = "redis://localhost:6379";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    postgresql
    redis
    nodejs_20
    yarn
    imagemagick
    git
    overmind
  ];

  # https://devenv.sh/languages/
  languages.ruby = {
    enable = true;
    version = "3.3.5";
  };

  # https://devenv.sh/processes/
  processes = {
    rails.exec = "bin/rails server -p 3000 -b 0.0.0.0";
    tailwind.exec = "bin/rails tailwindcss:watch";
  };

  # https://devenv.sh/services/
  services.postgres = {
    enable = true;
    package = pkgs.postgresql_15;
    listen_addresses = "127.0.0.1";
    port = 5432;
    initialDatabases = [
      { name = "churchmanager_development"; }
      { name = "churchmanager_test"; }
    ];
    initialScript = ''
      CREATE USER postgres SUPERUSER;
      ALTER USER postgres PASSWORD 'a4qpdvb7';
    '';
  };

  services.redis = {
    enable = true;
    port = 6379;
  };

  # https://devenv.sh/scripts/
  scripts = {
    start-services.exec = ''
      echo "🚀 [$(date)] Iniciando serviços..."
      devenv processes up
    '';

    setup.exec = ''
      echo "🚀 [$(date)] Iniciando configuração da aplicação Rails..."
      
      # Verificar se Ruby está disponível
      echo "📋 [$(date)] Verificando Ruby..."
      ruby --version || { echo "❌ Ruby não encontrado"; exit 1; }
      
      # Instalar gems
      echo "📦 [$(date)] Verificando gems..."
      if [ ! -f "vendor/bundle/config" ]; then
        echo "📦 [$(date)] Configurando bundle path..."
        bundle config set --local path 'vendor/bundle'
        echo "📦 [$(date)] Instalando gems..."
        bundle install || { echo "❌ Falha ao instalar gems"; exit 1; }
      else
        echo "📦 [$(date)] Gems já configuradas, verificando..."
        bundle check || bundle install
      fi
      
      echo "⏳ [$(date)] Aguardando PostgreSQL estar disponível..."
      timeout_pg=60
      while ! pg_isready -h localhost -p 5432 > /dev/null 2>&1; do
        echo "⏳ [$(date)] PostgreSQL ainda não está pronto... ($timeout_pg s restantes)"
        sleep 2
        timeout_pg=$((timeout_pg - 2))
        if [ $timeout_pg -le 0 ]; then
          echo "❌ [$(date)] PostgreSQL não iniciou em tempo hábil"
          echo "🔍 [$(date)] Verificando se os serviços estão rodando..."
          echo "Execute: devenv processes up"
          exit 1
        fi
      done
      echo "✅ [$(date)] PostgreSQL está disponível!"
      
      echo "⏳ [$(date)] Aguardando Redis estar disponível..."
      timeout_redis=30
      while ! redis-cli ping > /dev/null 2>&1; do
        echo "⏳ [$(date)] Redis ainda não está pronto... ($timeout_redis s restantes)"
        sleep 2
        timeout_redis=$((timeout_redis - 2))
        if [ $timeout_redis -le 0 ]; then
          echo "❌ [$(date)] Redis não iniciou em tempo hábil"
          exit 1
        fi
      done
      echo "✅ [$(date)] Redis está disponível!"
      
      # Configurar banco de dados
      echo "🗄️ [$(date)] Configurando banco de dados..."
      if ! bundle exec rails db:version > /dev/null 2>&1; then
        echo "🗄️ [$(date)] Criando banco de dados..."
        bundle exec rails db:create || { echo "❌ Falha ao criar banco"; exit 1; }
        
        echo "🗄️ [$(date)] Executando migrações..."
        bundle exec rails db:migrate || { echo "❌ Falha ao executar migrações"; exit 1; }
        
        echo "🌱 [$(date)] Executando seeds..."
        bundle exec rails db:seed || { echo "❌ Falha ao executar seeds"; exit 1; }
      else
        echo "🗄️ [$(date)] Banco existe, executando migrações pendentes..."
        bundle exec rails db:migrate || { echo "❌ Falha ao executar migrações"; exit 1; }
      fi
      
      # Precompilar assets se necessário
      echo "🎨 [$(date)] Preparando assets..."
      bundle exec rails assets:precompile || { echo "⚠️ Falha ao precompilar assets (não crítico)"; }
      
      echo "✅ [$(date)] Aplicação configurada com sucesso!"
      echo "🌐 Acesse: http://localhost:3000"
    '';

    dev.exec = ''
      echo "🚀 Iniciando aplicação em modo desenvolvimento..."
      overmind start -f Procfile.dev
    '';

    console.exec = ''
      bundle exec rails console
    '';

    reset-db.exec = ''
      echo "🗑️ Resetando banco de dados..."
      bundle exec rails db:drop db:create db:migrate db:seed
      echo "✅ Banco resetado com sucesso!"
    '';

    health.exec = ''
      ./scripts/health-check.sh
    '';
  };

  enterShell = ''
    echo "🏗️ Ambiente Rails carregado!"
    echo ""
    echo "⚠️  IMPORTANTE: Inicie os serviços primeiro!"
    echo ""
    echo "Comandos disponíveis:"
    echo "  start-services      - Inicia PostgreSQL e Redis"
    echo "  devenv processes up - Inicia PostgreSQL e Redis (alternativo)"
    echo "  setup               - Configura a aplicação (após serviços)"
    echo "  dev                 - Inicia servidor de desenvolvimento"
    echo "  console             - Abre console Rails"
    echo "  reset-db            - Reseta o banco de dados"
    echo "  health              - Verifica saúde dos serviços"
    echo ""
    echo "Para começar:"
    echo "  1. start-services (ou devenv processes up)"
    echo "  2. setup"
  '';

  # https://devenv.sh/tasks/
  # Removendo execução automática para permitir controle manual
  # tasks = {
  #   "rails:setup".exec = "setup";
  #   "devenv:enterShell".after = [ "rails:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    bundle exec rails test
  '';

  # See full reference at https://devenv.sh/reference/options/
}
