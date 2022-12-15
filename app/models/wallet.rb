class Wallet < ApplicationRecord
  belongs_to :church
  has_many :movements

  enum kind_of: [:corrente, :poupanca, :caixa, :investimento, :dizimo]

  validates :name, :kind_of, :church_id, presence: true

end
