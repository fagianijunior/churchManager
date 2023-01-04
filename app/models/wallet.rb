class Wallet < ApplicationRecord
  belongs_to :church
  has_many :movements

  enum kind_of: { corrente: 0, poupanca: 1, caixa: 2, investimento: 3 } 

  validates :name, :kind_of, :church_id, presence: true

end
