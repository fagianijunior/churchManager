class Occupation < ApplicationRecord
  has_many :administrations
  has_many :users, through: :administrations

  validates :title, presence: true
end
