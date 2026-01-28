#!/usr/bin/env ruby

# Add Rails root to load path
require_relative '../config/environment'

puts "🔍 Verificando carteiras no banco..."
puts

wallets = Wallet.all
puts "Total de carteiras: #{wallets.count}"
puts

if wallets.any?
  puts "Carteiras encontradas:"
  wallets.each_with_index do |wallet, index|
    puts "  #{index + 1}. #{wallet.name} (#{wallet.kind_of}) - Igreja: #{wallet.church&.name}"
  end
else
  puts "❌ Nenhuma carteira encontrada!"
end

puts
puts "🔍 Verificando igrejas..."
churches = Church.all
puts "Total de igrejas: #{churches.count}"

if churches.any?
  churches.each do |church|
    puts "  - #{church.name} (#{church.fundation_date})"
  end
else
  puts "❌ Nenhuma igreja encontrada!"
end