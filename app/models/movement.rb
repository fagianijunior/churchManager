class Movement < ApplicationRecord
  belongs_to :wallet
  belongs_to :user, optional: true

  enum kind_of: [:entrada, :saida, :entre_contas] # :entre_contas cria saida na primeira conta e entrada na segunda conta

  validates :kind_of, :amount, :payment_date, :description, :wallet_id, presence: true


end
