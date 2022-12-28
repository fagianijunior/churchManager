class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable,
  # :registerable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
  belongs_to :church

  validates :first_name, :last_name, :gender, :contact_number, :email, :birth_date, :church_id, :address, presence: true

  enum gender: [:masculino, :feminino]
  enum marital_status: [:solteiro, :casado, :divorciado, :viuvo]

  def full_name
    "#{first_name} #{last_name}"
  end

  def age
    ((Time.zone.now - birth_date.to_time) / 1.year.seconds).floor
  end

  def is_member?
    !member_since.nil?
  end

  def is_baptized?
    !baptism_date.nil?
  end
end
