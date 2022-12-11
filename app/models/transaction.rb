class Transaction < ApplicationRecord
  belongs_to :wallet

  enum kind_of: [:entrada, :saida] # :entre_contas cria saida na primeira conta e entrada na segunda conta

  validates :kind_of, :amount, :payment_date, :description, :wallet_id, presence: true


end
