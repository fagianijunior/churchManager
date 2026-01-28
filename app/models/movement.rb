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
  
  # Custom validation to ensure correct amount signs based on movement type
  validate :validate_amount_sign_by_type
  
  # Callback to normalize amount before saving
  before_save :normalize_amount_by_type

  private

  def validate_amount_sign_by_type
    return unless amount.present? && kind_of.present?
    
    case kind_of
    when 'entrada'
      if amount < 0
        errors.add(:amount, 'deve ser positivo para movimentações de entrada')
      end
    when 'saida'
      if amount > 0
        errors.add(:amount, 'deve ser negativo para movimentações de saída')
      end
    end
  end

  def normalize_amount_by_type
    return unless amount.present? && kind_of.present?
    
    case kind_of
    when 'entrada'
      self.amount = amount.abs
    when 'saida'
      self.amount = -amount.abs
    end
  end

  public

  # Helper method to display amounts without sign prefixes for editing
  def amount_for_display
    amount.present? ? amount.abs : 0
  end

  # Helper method to get the correct amount based on type (for form processing)
  def self.process_amount_by_type(amount_value, movement_type)
    return 0 unless amount_value.present?
    
    amount_value = amount_value.to_f.abs
    
    case movement_type.to_s
    when 'entrada'
      amount_value
    when 'saida'
      -amount_value
    else
      amount_value
    end
  end

  # Check if movement is income type
  def income?
    kind_of == 'entrada'
  end

  # Check if movement is expense type  
  def expense?
    kind_of == 'saida'
  end
end