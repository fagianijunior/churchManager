class Wallet < ApplicationRecord
  belongs_to :church

  enum kind_of: [:corrente, :poupanca, :caixa, :investimento]

  validates :name, :kind_of, :church_id, presence: true

end
