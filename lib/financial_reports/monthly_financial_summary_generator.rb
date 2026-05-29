# frozen_string_literal: true

module FinancialReports
  class MonthlyFinancialSummaryGenerator
    def self.call
      new.call
    end

    def call
      movements = fetch_movements
      grouped = group_by_month(movements)

      sections = []
      sections << render_header
      sections << render_months(grouped)
      sections << render_general_summary(grouped)

      sections.compact.join("\n\n")
    end

    private

    def fetch_movements
      Movement
        .where.not(sub_kind_of: :entre_contas)
        .order(:payment_date)
    end

    def group_by_month(movements)
      movements.group_by { |m| [m.payment_date.year, m.payment_date.month] }
               .sort_by { |key, _| key }
               .map { |key, movs|
                 {
                   year: key[0],
                   month: key[1],
                   entradas: movs.select(&:income?).sort_by { |m| [m.payment_date, m.sub_kind_of] },
                   saidas: movs.select(&:expense?).sort_by(&:payment_date)
                 }
               }
    end

    def truncate_description(description)
      return "" if description.nil?
      if description.length > 50
        description[0...50] + "..."
      else
        description
      end
    end

    def render_header
      date = Formatter.format_date(Date.current)
      "# Resumo Financeiro Mensal\n\nData de geração: #{date}"
    end

    def render_months(grouped)
      return nil if grouped.empty?

      grouped.map.with_index { |month_data, index|
        section = render_month_section(month_data)
        if index < grouped.size - 1
          section + "\n\n---\n"
        else
          section
        end
      }.join("\n\n")
    end

    def render_month_section(month_data)
      label = format("%02d/%04d", month_data[:month], month_data[:year])
      lines = []
      lines << "## #{label}"

      # Entradas section - omitted if no entradas
      if month_data[:entradas].any?
        lines << ""
        lines << "### Entradas"
        lines << ""
        lines << render_movements_table(month_data[:entradas], type: :entrada)
        lines << ""
        lines << "**Total de entradas:** #{Formatter.format_currency(sum_entradas(month_data))}"
      end

      # Saídas section - always shown, empty table if no saídas
      lines << ""
      lines << "### Saídas"
      lines << ""
      if month_data[:saidas].any?
        lines << render_movements_table(month_data[:saidas], type: :saida)
      else
        lines << "| Data | Categoria | Valor | Descrição |"
        lines << "| :--- | :--- | ---: | :--- |"
      end
      lines << ""
      lines << "**Total de saídas:** #{Formatter.format_currency(sum_saidas(month_data))}"

      # Monthly summary
      lines << ""
      saldo = sum_entradas(month_data) - sum_saidas(month_data)
      lines << "**Resumo do mês:**"
      lines << "- Total de entradas: #{Formatter.format_currency(sum_entradas(month_data))}"
      lines << "- Total de saídas: #{Formatter.format_currency(sum_saidas(month_data))}"
      lines << "- Saldo: #{format_saldo(saldo)}"

      lines.join("\n")
    end

    def render_movements_table(movements, type:)
      lines = []
      lines << "| Data | Categoria | Valor | Descrição |"
      lines << "| :--- | :--- | ---: | :--- |"

      movements.each do |mov|
        date = Formatter.format_date(mov.payment_date)
        category = mov.sub_kind_of.humanize
        value = Formatter.format_currency(mov.amount.abs)
        description = truncate_description(mov.description)
        lines << "| #{date} | #{category} | #{value} | #{description} |"
      end

      lines.join("\n")
    end

    def sum_entradas(month_data)
      month_data[:entradas].sum { |m| m.amount }
    end

    def sum_saidas(month_data)
      month_data[:saidas].sum { |m| m.amount.abs }
    end

    def format_saldo(value)
      if value < 0
        "-#{Formatter.format_currency(value.abs)}"
      else
        Formatter.format_currency(value)
      end
    end

    def render_general_summary(grouped)
      total_entradas = grouped.sum { |m| sum_entradas(m) }
      total_saidas = grouped.sum { |m| sum_saidas(m) }
      saldo_geral = total_entradas - total_saidas
      month_count = grouped.size

      lines = []
      lines << "## Resumo Geral"
      lines << ""
      lines << "| Indicador | Valor |"
      lines << "| :--- | ---: |"
      lines << "| Total de entradas | #{Formatter.format_currency(total_entradas)} |"
      lines << "| Total de saídas | #{Formatter.format_currency(total_saidas)} |"
      lines << "| Saldo geral | #{format_saldo(saldo_geral)} |"
      lines << "| Meses com movimentações | #{month_count} |"

      lines.join("\n")
    end
  end
end
