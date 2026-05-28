# frozen_string_literal: true

module FinancialReports
  class SalariesReportGenerator
    def self.call
      new.call
    end

    def call
      administrations = fetch_administrations
      active_administrations = administrations.select { |a| a.end_date.nil? }

      content = []
      content << render_header
      content << ""

      if administrations.any?
        administrations.each_with_index do |administration, index|
          content << render_employee_section(administration)
          content << "" unless index == administrations.size - 1
          content << "---" unless index == administrations.size - 1
          content << "" unless index == administrations.size - 1
        end
      end

      content << ""
      content << render_summary(active_administrations)
      content << ""

      content.join("\n")
    end

    private

    def fetch_administrations
      Administration
        .joins(:user, :occupation)
        .where.not(salary: nil)
        .where("salary > 0")
        .includes(:user, :occupation)
        .order("users.first_name ASC, users.last_name ASC")
    end

    def render_header
      lines = []
      lines << "# Relatório de Salários"
      lines << ""
      lines << "Data de geração: #{Formatter.format_date(Date.today)}"
      lines.join("\n")
    end

    def render_employee_section(administration)
      user = administration.user
      occupation = administration.occupation
      name = Formatter.full_name(user)
      salary = Formatter.format_currency(administration.salary)
      payment_day = administration.payment_day.present? ? administration.payment_day.to_s : "Não definido"
      start_date = Formatter.format_date(administration.start_date)
      end_date = administration.end_date.nil? ? "Em atividade" : Formatter.format_date(administration.end_date)

      lines = []
      lines << "## #{name}"
      lines << ""
      lines << "| Campo | Valor |"
      lines << "| :--- | ---: |"
      lines << "| Nome | #{name} |"
      lines << "| Cargo | #{occupation.title} |"
      lines << "| Salário | #{salary} |"
      lines << "| Dia de Pagamento | #{payment_day} |"
      lines << "| Data de Início | #{start_date} |"
      lines << "| Data de Término | #{end_date} |"
      lines << ""
      lines.join("\n")
    end

    def render_summary(active_administrations)
      total_active = active_administrations.size
      total_salary = active_administrations.sum { |a| a.salary.to_f }

      lines = []
      lines << "## Resumo"
      lines << ""
      lines << "| Indicador | Valor |"
      lines << "| :--- | ---: |"
      lines << "| Total de funcionários ativos | #{total_active} |"
      lines << "| Soma dos salários ativos | #{Formatter.format_currency(total_salary)} |"
      lines << ""
      lines.join("\n")
    end
  end
end
