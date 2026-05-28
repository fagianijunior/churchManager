# frozen_string_literal: true

module FinancialReports
  module Formatter
    module_function

    # Converte BigDecimal/Float para formato brasileiro "R$ 1.234,56"
    def format_currency(value)
      return "R$ 0,00" if value.nil? || value.zero?

      formatted = format("%.2f", value.abs)
      integer_part, decimal_part = formatted.split(".")
      integer_with_dots = integer_part.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
      "R$ #{integer_with_dots},#{decimal_part}"
    end

    # Converte Date/DateTime para "dd/mm/aaaa"
    def format_date(date)
      return nil if date.nil?

      date.strftime("%d/%m/%Y")
    end

    # Retorna nome completo, tratando last_name nulo/vazio
    def full_name(user)
      if user.last_name.blank?
        user.first_name
      else
        "#{user.first_name} #{user.last_name}"
      end
    end
  end
end
