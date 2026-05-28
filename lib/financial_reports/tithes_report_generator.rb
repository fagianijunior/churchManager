# frozen_string_literal: true

module FinancialReports
  class TithesReportGenerator
    def self.call
      new.call
    end

    def call
      tithes = fetch_tithes
      grouped = group_by_member(tithes)
      member_tithes = grouped[:members]
      orphan_tithes = grouped[:orphans]

      sections = []
      sections << render_header
      sections << render_members(member_tithes)
      sections << render_orphan_section(orphan_tithes) if orphan_tithes.any?
      sections << render_summary(member_tithes.size, total_amount(tithes))

      sections.compact.join("\n\n---\n\n")
    end

    private

    def fetch_tithes
      Movement.where(sub_kind_of: :dízimo).includes(:user).order(:payment_date)
    end

    def group_by_member(tithes)
      members = {}
      orphans = []

      tithes.each do |tithe|
        if tithe.user_id.nil?
          orphans << tithe
        else
          members[tithe.user_id] ||= { user: tithe.user, tithes: [] }
          members[tithe.user_id][:tithes] << tithe
        end
      end

      sorted_members = members.values.sort_by { |entry| Formatter.full_name(entry[:user]).downcase }

      { members: sorted_members, orphans: orphans }
    end

    def render_header
      date = Formatter.format_date(Date.current)
      "# Relatório de Dízimos por Membro\n\n**Data de geração:** #{date}"
    end

    def render_members(member_tithes)
      return nil if member_tithes.empty?

      member_tithes.map { |entry| render_member_section(entry[:user], entry[:tithes]) }.join("\n\n---\n\n")
    end

    def render_member_section(user, tithes)
      name = Formatter.full_name(user)
      count = tithes.size
      total = tithes.sum(&:amount)
      sorted_tithes = tithes.sort_by(&:payment_date)

      lines = []
      lines << "## #{name}"
      lines << ""
      lines << "**Quantidade de dízimos:** #{count}"
      lines << "**Valor total:** #{Formatter.format_currency(total)}"
      lines << ""
      lines << render_tithes_table(sorted_tithes)

      lines.join("\n")
    end

    def render_tithes_table(tithes)
      lines = []
      lines << "| Data | Valor | Descrição |"
      lines << "| :--- | ---: | :--- |"

      tithes.each do |tithe|
        date = Formatter.format_date(tithe.payment_date)
        value = Formatter.format_currency(tithe.amount)
        description = tithe.description || ""
        lines << "| #{date} | #{value} | #{description} |"
      end

      lines.join("\n")
    end

    def render_orphan_section(tithes)
      return nil if tithes.empty?

      sorted_tithes = tithes.sort_by(&:payment_date)
      count = tithes.size
      total = tithes.sum(&:amount)

      lines = []
      lines << "## Dízimos sem membro identificado"
      lines << ""
      lines << "**Quantidade de dízimos:** #{count}"
      lines << "**Valor total:** #{Formatter.format_currency(total)}"
      lines << ""
      lines << render_tithes_table(sorted_tithes)

      lines.join("\n")
    end

    def render_summary(members_count, total_amount)
      lines = []
      lines << "## Resumo Geral"
      lines << ""
      lines << "**Total de membros contribuintes:** #{members_count}"
      lines << "**Valor total de todos os dízimos:** #{Formatter.format_currency(total_amount)}"

      lines.join("\n")
    end

    def total_amount(tithes)
      tithes.sum(&:amount)
    end
  end
end
