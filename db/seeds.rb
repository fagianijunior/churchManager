# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# Buscar ou criar igreja
church = Church.find_or_create_by(name: "Maranata") do |c|
  c.fundation_date = "1980-11-10"
end

puts "Igreja: #{church.name} (ID: #{church.id})"

# Criar carteiras se não existirem
wallets_data = [
  { name: "Local", kind_of: :caixa },
  { name: "Cora", kind_of: :corrente }
]

wallets_data.each do |wallet_data|
  wallet = Wallet.find_or_create_by(name: wallet_data[:name], church: church) do |w|
    w.kind_of = wallet_data[:kind_of]
  end
  
  if wallet.persisted?
    puts "Carteira criada/encontrada: #{wallet.name}"
  else
    puts "Erro ao criar carteira #{wallet_data[:name]}: #{wallet.errors.full_messages.join(', ')}"
  end
end

if Rails.env.development?
  occupations = Occupation.create([
    {
      title: 'Presidente'
    }, {
      title: 'Diácono'
    }, {
      title: 'Secretaria'
    }, {
      title: 'Tesouraria'
    }, {
      title: 'Conselho fiscal'
    }, {
      title: 'Diretor (E.B.D.)'
    }, {
      title: 'Secretaria (E.B.D.)'
    }, {
      title: 'Mídia'
    }, {
      title: 'Departamento infantil (E.B.D.)'
    }, {
      title: 'Professor dos adultos'
    }, {
      title: 'Professor dos Jovens'
    }, {
      title: 'Mocidade'
    }, {
      title: 'Evangelismo'
    }, {
      title: 'Diretor do louvor'
    }, {
      title: 'Departamento infantil (Noite)'
    }, {
      title: 'Sociabilidade'
    }, {
      title: 'Encontro de casais'
    }, {
      title: 'Zeladoria'
    }
  ])
  
  users = User.find_or_create_by(
    {
      first_name: "Carlos",
      last_name: "Fagiani Junior",
      birth_date: "1985-10-28",
      gender: :masculino,
      marital_status: :casado,
      address: "Rua 03H, 199 - Monte Prince II, B.J, C.03 - Passaré - Fortaleza - CE, 60749-050",
      baptism_date: "",
      member_since: "",
      contact_number: "(85) 98595-2866",
      church: church,
      email: 'fagianijunior@gmail.com',
      cpf: '01818382300',
      rg: '2000010575589',
      description: ''
    }
  )
end