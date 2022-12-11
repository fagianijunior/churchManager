class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable,
  # :registerable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
  belongs_to :church

  validates :first_name, :last_name, :gender, :contact_number, :email, :birth_date, :church_id, :address, presence: true

  # Gender enum
  enum gender: [:masculino, :feminino]

  def full_name
    "#{first_name} #{last_name}"
  end
end
