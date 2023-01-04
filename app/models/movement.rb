class Movement < ApplicationRecord
  belongs_to :wallet
  belongs_to :user, optional: true

  enum kind_of: { entrada: 1, saida: 2 }
  enum sub_kind_of: { dizimo: 1, oferta: 2, outras_entradas: 3, entre_contas: 101, compra: 201, funcionario: 201, outros_gastos: 202 }
  validates :kind_of, :sub_kind_of, :amount, :payment_date, :description, :wallet_id, presence: true


end
