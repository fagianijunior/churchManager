class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable,
  # :registerable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
  belongs_to :church

  has_one_attached :avatar do |attachable|
    attachable.variant :micro, resize_to_limit: [50, 50]
    attachable.variant :small, resize_to_limit: [150, 150]
    attachable.variant :medium, resize_to_limit: [500, 500]
    attachable.variant :large, resize_to_limit: [1024, 1024]
  end

  has_many :administrations
  has_many :occupations, through: :administrations
  has_many :movements
  validates :first_name, :last_name, :gender, :marital_status, :contact_number, :email, :birth_date, :church_id, :address, presence: true

  enum gender: [:masculino, :feminino]
  enum marital_status: [:solteiro, :casado, :separado, :divorciado, :viuvo]

  before_validation :validate_password

  def validate_password
    self.password = SecureRandom.hex(5) if encrypted_password.empty?
  end
  

  def full_name
    "#{first_name} #{last_name}"
  end
  
  def name
    full_name
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
