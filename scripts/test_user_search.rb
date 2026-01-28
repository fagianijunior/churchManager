#!/usr/bin/env ruby

# Script para testar a funcionalidade de busca de usuários
puts "🔍 Testando funcionalidade de busca de usuários..."

# Verificar se há usuários no banco
users_count = User.count
puts "📊 Total de usuários no banco: #{users_count}"

if users_count == 0
  puts "❌ Nenhum usuário encontrado no banco de dados"
  exit 1
end

# Testar scope search_by_name
puts "\n🔍 Testando busca por nome..."
test_names = ["Carlos", "Maria", "Ana", "José"]

test_names.each do |name|
  results = User.search_by_name(name)
  puts "  Busca por '#{name}': #{results.count} resultados"
  results.limit(3).each do |user|
    puts "    - #{user.full_name} (#{user.email})"
  end
end

# Testar scope recently_used_in_movements
puts "\n📈 Testando usuários recentes em movimentações..."
recent_users = User.recently_used_in_movements
puts "  Usuários recentes: #{recent_users.count}"
recent_users.each do |user|
  puts "    - #{user.full_name}"
end

# Testar método as_search_result
puts "\n🔧 Testando formatação para JSON..."
sample_user = User.first
if sample_user
  result = sample_user.as_search_result
  puts "  Exemplo de resultado JSON:"
  puts "    ID: #{result[:id]}"
  puts "    Nome: #{result[:name]}"
  puts "    Email: #{result[:email]}"
  puts "    É membro: #{result[:is_member]}"
  puts "    Membro desde: #{result[:member_since]}"
end

# Verificar se há movimentações
movements_count = Movement.count
puts "\n📊 Total de movimentações: #{movements_count}"

puts "\n✅ Teste concluído!"