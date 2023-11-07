class Movement < ApplicationRecord
  belongs_to :wallet
  belongs_to :user, optional: true

  has_one_attached :receipt do |attachable|
    attachable.variant :thumb, resize_to_limit: [250, 250]
  end

  enum kind_of: { entrada: 1, saida: 2 }
  enum sub_kind_of: {
    dízimo: 1,
    oferta: 2,
    outras_entradas: 3,
    juros_positivo: 4,
    
    entre_contas: 101,
    
    compra: 201,
    outros_gastos: 202,
    funcionario: 203,
    serviço_público: 204,
    chá_da_comunhão: 205,
    reforma: 206,
    dep_louvor: 207,
    dep_casais: 208,
    dep_infantil: 209,
    mocidade: 210,
    juros_negativo: 211
  }
  validates :kind_of, :sub_kind_of, :amount, :payment_date, :description, :wallet_id, presence: true
end