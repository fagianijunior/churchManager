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

  # Search scope for name-based searching
  scope :search_by_name, ->(term) { 
    where("CONCAT(first_name, ' ', last_name) ILIKE ?", "%#{term}%") if term.present?
  }

  # Get recently used members from movements (last 30 days)
  scope :recently_used_in_movements, -> {
    joins(:movements)
      .where(movements: { created_at: 30.days.ago..Time.current })
      .group('users.id')
      .order('MAX(movements.created_at) DESC')
      .limit(10)
  }

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

  # Helper method for formatted display in search results
  def search_display_info
    info_parts = [full_name]
    info_parts << email if email.present?
    info_parts << "Membro desde #{member_since.strftime('%d/%m/%Y')}" if is_member?
    info_parts.join(' - ')
  end

  # Method to get user data for JSON API responses
  def as_search_result
    {
      id: id,
      name: full_name,
      email: email,
      display_info: search_display_info,
      is_member: is_member?,
      member_since: member_since&.strftime('%d/%m/%Y')
    }
  end
end
