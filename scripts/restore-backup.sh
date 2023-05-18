#!/bin/bash
timestamp=$(date +%d%m%Y-%H%M)
echo "Timestamp: $timestamp"

file_name=$(aws s3api list-objects --bucket ibrmaranata-db-backups --query 'sort_by(Contents, &LastModified)[-1].Key' --output text --profile fagianijunior) 

aws s3 cp s3://ibrmaranata-db-backups/$file_name /tmp/$file_name --profile fagianijunior

echo "Removendo base de dados de desenvolvimento"
psql -h localhost -c "DROP DATABASE churchmanager_development"

echo "Recriando base de dados de desenvolvimento"
psql -h localhost -c "CREATE DATABASE churchmanager_development"

echo "Populando base de dados de desenvolvimento"
psql -h localhost -d churchmanager_development < "/tmp/$file_name"
