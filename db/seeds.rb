# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
church = Church.create ({
  name: "Maranata",
  fundation_date: "1980-11-10"
})
user = User.create([{
  first_name: "Carlos",
  last_name: "Fagiani Junior",
  gender: true,
  address: "Rua 03H, 199 - Monte Prince II, B.J, C.03 - Fortaleza - CE",
  birth_date: "1985-10-28",
  contact_number: "(85) 98595-2866",
  church: church,
  email: 'adm@adm.com',
  password: '1qaz2wsx',
  password_confirmation: '1qaz2wsx'
}])