#!/bin/bash
timestamp=$(date +%d%m%Y-%H%M)
echo "Timestamp: $timestamp"

echo "Criando backup da base de dados"
pg_dump -h localhost -U postgres -d churchmanager_production -f "/tmp/churchmanager_production-$timestamp.sql"

echo "Enviando backup para S3"
aws s3 cp "/tmp/churchmanager_production-$timestamp.sql" s3://ibrmaranata-db-backups/

#echo "Removendo base de dados de desenvolvimento"
#psql -h localhost -c "DROP DATABASE churchmanager_development"

#echo "Recriando base de dados de desenvolvimento"
#psql -h localhost -c "CREATE DATABASE churchmanager_development"

#echo "Populando base de dados de desenvolvimento"
#psql -h localhost -d churchmanager_development < "/tmp/churchManager_production-$timestamp.sql"