# frozen_string_literal: true

require "spec_helper"
require "rantly"
require "rantly/rspec_extensions"
require "bigdecimal"
require "ostruct"
require "date"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/date/calculations"
require "active_support/core_ext/string/inflections"
require_relative "../../../lib/financial_reports/formatter"
require_relative "../../../lib/financial_reports/monthly_financial_summary_generator"

# Stub Movement class for tests that don't load Rails
class Movement; end unless defined?(Movement)

RSpec.describe FinancialReports::MonthlyFinancialSummaryGenerator do
  # Valid sub_kind_of values for entradas (excluding entre_contas)
  ENTRADA_SUB_KINDS = %w[dízimo oferta outras_entradas juros_positivo].freeze
  # Valid sub_kind_of values for saídas (excluding entre_contas)
  SAIDA_SUB_KINDS = %w[compra outros_gastos funcionario serviço_público chá_da_comunhão reforma dep_louvor dep_casais dep_infantil mocidade juros_negativo].freeze

  # Helper to build a mock Movement object
  def build_movement(kind_of:, sub_kind_of:, amount:, payment_date:, description: "Movimento")
    amount_value = kind_of == "entrada" ? amount.abs : -amount.abs
    OpenStruct.new(
      kind_of: kind_of,
      sub_kind_of: sub_kind_of,
      amount: amount_value,
      payment_date: payment_date,
      description: description
    ).tap do |mov|
      mov.define_singleton_method(:income?) { kind_of == "entrada" }
      mov.define_singleton_method(:expense?) { kind_of == "saida" }
    end
  end

  describe "Property 1: Exclusão de movimentações entre_contas" do
    # Feature: monthly-financial-summary, Property 1: Exclusão de movimentações entre_contas
    # **Validates: Requirements 2.1**
    #
    # For any set of movements that includes records with sub_kind_of: :entre_contas,
    # the generated report SHALL NOT contain any movement with that subcategory —
    # no table row should correspond to an entre_contas movement.
    it "excludes all entre_contas movements from the report" do
      property_of {
        # Generate between 1 and 5 regular movements
        num_regular = range(1, 5)
        # Generate between 1 and 5 entre_contas movements
        num_entre_contas = range(1, 5)

        regular_movements_data = []
        entre_contas_descriptions = []

        # Generate regular movements (entradas and saidas)
        num_regular.times do |i|
          is_entrada = range(0, 1) == 0
          cents = range(100, 100_000)
          amount = BigDecimal(cents.to_s) / BigDecimal("100")
          sub_kind = is_entrada ? ENTRADA_SUB_KINDS[range(0, ENTRADA_SUB_KINDS.size - 1)] : SAIDA_SUB_KINDS[range(0, SAIDA_SUB_KINDS.size - 1)]

          regular_movements_data << {
            kind: is_entrada ? "entrada" : "saida",
            sub_kind: sub_kind,
            amount: amount,
            month: range(1, 12),
            day: range(1, 28),
            description: "Regular_#{i}_#{range(1000, 9999)}"
          }
        end

        # Generate entre_contas movements with unique descriptions to identify them
        num_entre_contas.times do |i|
          desc = "ENTRE_CONTAS_MARKER_#{i}_#{range(1000, 9999)}"
          entre_contas_descriptions << desc
        end

        [regular_movements_data, entre_contas_descriptions]
      }.check(100) do |regular_movements_data, entre_contas_descriptions|
        # Build only the regular movements (simulating what fetch_movements returns after filtering)
        movements = regular_movements_data.map do |m|
          build_movement(
            kind_of: m[:kind],
            sub_kind_of: m[:sub_kind],
            amount: m[:amount],
            payment_date: Date.new(2024, m[:month], m[:day]),
            description: m[:description]
          )
        end

        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 6, 15))

        report = generator.call

        # Verify no entre_contas description appears in the report
        entre_contas_descriptions.each do |desc|
          expect(report).not_to include(desc),
            "Report should not contain entre_contas movement with description '#{desc}'"
        end

        # Verify the category "Entre contas" (humanized form) does not appear in table rows
        report.lines.each do |line|
          next unless line.start_with?("|") && !line.include?("---") && !line.include?("Data") && !line.include?("Indicador")
          expect(line).not_to include("Entre contas"),
            "Table row should not contain 'Entre contas' category: #{line}"
        end
      end
    end
  end

  describe "Property 2: Ordenação cronológica de meses com formato correto" do
    # Feature: monthly-financial-summary, Property 2: Ordenação cronológica de meses com formato correto
    # **Validates: Requirements 2.2, 2.3**
    #
    # For any set of movements spanning multiple months, the month sections in the
    # report SHALL appear in chronological ascending order, and each section header
    # SHALL be in "MM/AAAA" format (with leading zero for single-digit months).
    it "orders month sections chronologically with MM/AAAA format" do
      property_of {
        # Generate between 2 and 6 distinct months
        num_months = range(2, 6)
        months_set = []

        while months_set.size < num_months
          year = range(2020, 2025)
          month = range(1, 12)
          months_set << [year, month] unless months_set.include?([year, month])
        end

        movements_data = []
        months_set.each do |year, month|
          # Generate 1-3 movements per month
          num_movs = range(1, 3)
          max_day = Date.new(year, month, -1).day
          num_movs.times do |i|
            is_entrada = range(0, 1) == 0
            cents = range(100, 100_000)
            amount = BigDecimal(cents.to_s) / BigDecimal("100")
            sub_kind = is_entrada ? ENTRADA_SUB_KINDS[range(0, ENTRADA_SUB_KINDS.size - 1)] : SAIDA_SUB_KINDS[range(0, SAIDA_SUB_KINDS.size - 1)]
            day = range(1, max_day)

            movements_data << {
              kind: is_entrada ? "entrada" : "saida",
              sub_kind: sub_kind,
              amount: amount,
              year: year,
              month: month,
              day: day
            }
          end
        end

        [movements_data, months_set]
      }.check(100) do |movements_data, months_set|
        movements = movements_data.map do |m|
          build_movement(
            kind_of: m[:kind],
            sub_kind_of: m[:sub_kind],
            amount: m[:amount],
            payment_date: Date.new(m[:year], m[:month], m[:day]),
            description: "Mov test"
          )
        end

        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 6, 15))

        report = generator.call

        # Extract all month section headers (## MM/AAAA)
        month_headers = report.scan(/^## (\d{2}\/\d{4})$/).flatten

        # Verify format: each header must be MM/AAAA with leading zero
        month_headers.each do |header|
          expect(header).to match(/^\d{2}\/\d{4}$/),
            "Month header '#{header}' should be in MM/AAAA format"
          month_num = header.split("/").first.to_i
          expect(month_num).to be_between(1, 12),
            "Month number #{month_num} should be between 1 and 12"
        end

        # Verify chronological order
        parsed_dates = month_headers.map do |h|
          parts = h.split("/")
          [parts[1].to_i, parts[0].to_i] # [year, month]
        end

        parsed_dates.each_cons(2) do |prev, curr|
          prev_comparable = prev[0] * 100 + prev[1]
          curr_comparable = curr[0] * 100 + curr[1]
          expect(curr_comparable).to be > prev_comparable,
            "Months should be in chronological order: #{format('%02d/%04d', prev[1], prev[0])} should come before #{format('%02d/%04d', curr[1], curr[0])}"
        end

        # Verify all generated months are present
        expected_labels = months_set.map { |y, m| format("%02d/%04d", m, y) }
          .sort_by { |l| parts = l.split("/"); [parts[1].to_i, parts[0].to_i] }
        expect(month_headers).to eq(expected_labels),
          "All months with movements should appear in the report in chronological order"
      end
    end
  end

  describe "Property 7: Truncamento de descrição em 50 caracteres" do
    # Feature: monthly-financial-summary, Property 7: Truncamento de descrição em 50 caracteres
    # **Validates: Requirements 3.2**
    #
    # For any movement with description longer than 50 characters, the displayed
    # description SHALL have exactly 53 characters (50 + "..."). For descriptions
    # with 50 characters or less, SHALL be displayed in full without modification.
    it "truncates descriptions longer than 50 chars and preserves shorter ones" do
      property_of {
        # Generate a description length: either <= 50 or > 50
        is_long = range(0, 1) == 0
        if is_long
          # Generate description between 51 and 150 characters
          desc_length = range(51, 150)
        else
          # Generate description between 1 and 50 characters
          desc_length = range(1, 50)
        end

        # Generate a description of the exact length using alphanumeric chars
        description = sized(desc_length) { string(:alnum) }

        [description, is_long]
      }.check(100) do |description, is_long|
        # Build a single entrada movement with the generated description
        movement = build_movement(
          kind_of: "entrada",
          sub_kind_of: "dízimo",
          amount: BigDecimal("100.00"),
          payment_date: Date.new(2024, 3, 15),
          description: description
        )

        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return([movement])
        allow(Date).to receive(:current).and_return(Date.new(2024, 6, 15))

        report = generator.call

        if is_long
          # Description > 50 chars: should be truncated to 50 + "..." = 53 chars
          truncated = description[0...50] + "..."
          expect(truncated.length).to eq(53),
            "Truncated description should be exactly 53 characters"
          expect(report).to include(truncated),
            "Long description (#{description.length} chars) should be truncated to '#{truncated}'"
          # The full description should NOT appear
          expect(report).not_to include(description),
            "Full long description should not appear in report"
        else
          # Description <= 50 chars: should appear in full
          expect(report).to include(description),
            "Short description (#{description.length} chars) '#{description}' should appear in full in report"
        end
      end
    end
  end

  describe "Property 3: Entradas corretamente formatadas e ordenadas dentro de cada mês" do
    # Feature: monthly-financial-summary, Property 3: Entradas corretamente formatadas e ordenadas dentro de cada mês
    # **Validates: Requirements 3.1, 3.2, 3.3**
    #
    # For any set of entrada movements in a given month, each entrada SHALL appear
    # in the table with formatted date (dd/mm/aaaa), humanized subcategory, formatted
    # value (R$ X.XXX,XX), and description (truncated at 50 chars with "..." when exceeding).
    # Entradas SHALL be ordered by date ascending and, for same date, by subcategory alphabetically.
    it "displays entradas with correct formatting and ordering within each month" do
      property_of {
        # Generate a random month/year
        year = range(2020, 2025)
        month = range(1, 12)
        max_day = Date.new(year, month, -1).day

        # Generate between 2 and 10 entrada movements for this month
        num_entradas = range(2, 10)

        entradas_data = Array.new(num_entradas) do
          day = range(1, max_day)
          sub_kind = ENTRADA_SUB_KINDS[range(0, ENTRADA_SUB_KINDS.size - 1)]
          cents = range(1, 999_999)
          amount = BigDecimal(cents.to_s) / BigDecimal("100")

          # Generate description with variable length (some > 50 chars, some <= 50)
          desc_length = range(5, 70)
          description = sized(desc_length) { string(:alpha) }

          { day: day, sub_kind: sub_kind, amount: amount, description: description }
        end

        [year, month, max_day, entradas_data]
      }.check(100) do |year, month, max_day, entradas_data|
        # Build mock movements
        movements = entradas_data.map do |e|
          build_movement(
            kind_of: "entrada",
            sub_kind_of: e[:sub_kind],
            amount: e[:amount],
            payment_date: Date.new(year, month, e[:day]),
            description: e[:description]
          )
        end

        # Create generator instance and stub fetch_movements
        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        report = generator.call

        # Find the month section
        month_label = format("%02d/%04d", month, year)
        expect(report).to include("## #{month_label}")

        # Extract the Entradas table section
        entradas_section = report.split("### Entradas").last.split("###").first

        # Verify each entrada appears with correct formatting
        movements.each do |mov|
          expected_date = FinancialReports::Formatter.format_date(mov.payment_date)
          expected_category = mov.sub_kind_of.humanize
          expected_value = FinancialReports::Formatter.format_currency(mov.amount.abs)

          # Verify description truncation
          if mov.description.length > 50
            expected_desc = mov.description[0...50] + "..."
          else
            expected_desc = mov.description
          end

          expected_row = "| #{expected_date} | #{expected_category} | #{expected_value} | #{expected_desc} |"
          expect(entradas_section).to include(expected_row),
            "Expected entradas section to contain row:\n#{expected_row}\n\nActual section:\n#{entradas_section}"
        end

        # Verify ordering: extract table rows and check order
        table_rows = entradas_section.lines.select { |line| line.match?(/^\| \d{2}\/\d{2}\/\d{4}/) }

        # Expected order: by date ascending, then by sub_kind_of alphabetically for same date
        expected_order = movements.sort_by { |m| [m.payment_date, m.sub_kind_of] }

        expected_order.each_with_index do |mov, idx|
          expected_date = FinancialReports::Formatter.format_date(mov.payment_date)
          expected_category = mov.sub_kind_of.humanize
          expect(table_rows[idx]).to start_with("| #{expected_date} | #{expected_category} |"),
            "Row #{idx} should start with date #{expected_date} and category #{expected_category}, got: #{table_rows[idx]}"
        end
      end
    end
  end

  describe "Property 4: Saídas corretamente formatadas com valores absolutos e ordenadas" do
    # Feature: monthly-financial-summary, Property 4: Saídas corretamente formatadas com valores absolutos e ordenadas
    # **Validates: Requirements 4.1, 4.2, 4.3**
    #
    # For any set of saída movements in a given month, each saída SHALL appear in
    # the table with the absolute value formatted (never negative), and saídas SHALL
    # be ordered by payment_date in chronological ascending order.
    it "displays saídas with absolute values and ordered by payment_date ascending" do
      property_of {
        # Generate a random month/year
        year = range(2020, 2025)
        month = range(1, 12)
        max_day = Date.new(year, month, -1).day

        # Generate between 2 and 10 saída movements for this month
        num_saidas = range(2, 10)

        saidas_data = Array.new(num_saidas) do
          day = range(1, max_day)
          sub_kind = SAIDA_SUB_KINDS[range(0, SAIDA_SUB_KINDS.size - 1)]
          cents = range(1, 999_999)
          amount = BigDecimal(cents.to_s) / BigDecimal("100")

          desc_length = range(5, 40)
          description = sized(desc_length) { string(:alpha) }

          { day: day, sub_kind: sub_kind, amount: amount, description: description }
        end

        [year, month, max_day, saidas_data]
      }.check(100) do |year, month, max_day, saidas_data|
        # Build mock movements (saídas have negative amounts)
        movements = saidas_data.map do |s|
          build_movement(
            kind_of: "saida",
            sub_kind_of: s[:sub_kind],
            amount: s[:amount],
            payment_date: Date.new(year, month, s[:day]),
            description: s[:description]
          )
        end

        # Create generator instance and stub fetch_movements
        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        report = generator.call

        # Find the month section
        month_label = format("%02d/%04d", month, year)
        expect(report).to include("## #{month_label}")

        # Extract the Saídas table section
        saidas_section = report.split("### Saídas").last.split("**Total de saídas:**").first

        # Verify each saída appears with absolute value (never negative)
        movements.each do |mov|
          expected_date = FinancialReports::Formatter.format_date(mov.payment_date)
          expected_category = mov.sub_kind_of.humanize
          # Value MUST be absolute (positive) even though model stores negative
          expected_value = FinancialReports::Formatter.format_currency(mov.amount.abs)

          # Verify the value does NOT contain a negative sign
          expect(expected_value).not_to start_with("-"),
            "Saída value should be absolute (positive), got: #{expected_value}"

          expected_row = "| #{expected_date} | #{expected_category} | #{expected_value} | #{mov.description} |"
          expect(saidas_section).to include(expected_row),
            "Expected saídas section to contain row:\n#{expected_row}\n\nActual section:\n#{saidas_section}"
        end

        # Verify ordering by payment_date ascending
        table_rows = saidas_section.lines.select { |line| line.match?(/^\| \d{2}\/\d{2}\/\d{4}/) }

        expected_order = movements.sort_by(&:payment_date)

        expected_order.each_with_index do |mov, idx|
          expected_date = FinancialReports::Formatter.format_date(mov.payment_date)
          expect(table_rows[idx]).to start_with("| #{expected_date} |"),
            "Row #{idx} should start with date #{expected_date}, got: #{table_rows[idx]}"
        end

        # Additional check: no negative values in any table row
        table_rows.each do |row|
          expect(row).not_to match(/\| -R\$/),
            "Found negative value in saídas table row: #{row}"
        end
      end
    end
  end

  describe "Property 5: Totais mensais corretos (entradas, saídas e saldo)" do
    # Feature: monthly-financial-summary, Property 5: Totais mensais corretos (entradas, saídas e saldo)
    # **Validates: Requirements 3.4, 4.4, 5.1, 5.2, 5.3**
    #
    # For any month with movements, the total entradas displayed SHALL equal the sum
    # of amounts of entradas for that month, the total saídas SHALL equal the sum of
    # absolute values of saída amounts, and the saldo SHALL equal (total_entradas - total_saídas).
    # When saldo is negative, SHALL be displayed as "-R$ X.XXX,XX".
    it "displays correct monthly totals for entradas, saídas and saldo" do
      property_of {
        # Generate movements for a single month
        year = range(2020, 2025)
        month = range(1, 12)
        max_day = Date.new(year, month, -1).day

        # Generate between 1 and 5 entradas
        num_entradas = range(1, 5)
        entradas = Array.new(num_entradas) do
          cents = range(1, 999_999)
          amount = BigDecimal(cents.to_s) / BigDecimal("100")
          day = range(1, max_day)
          sub_kind = ENTRADA_SUB_KINDS.sample
          { amount: amount, day: day, sub_kind: sub_kind }
        end

        # Generate between 1 and 5 saídas
        num_saidas = range(1, 5)
        saidas = Array.new(num_saidas) do
          cents = range(1, 999_999)
          amount = BigDecimal(cents.to_s) / BigDecimal("100")
          day = range(1, max_day)
          sub_kind = SAIDA_SUB_KINDS.sample
          { amount: amount, day: day, sub_kind: sub_kind }
        end

        [year, month, max_day, entradas, saidas]
      }.check(100) do |year, month, max_day, entradas_data, saidas_data|
        # Build mock movements
        movements = []

        entradas_data.each do |e|
          movements << build_movement(
            kind_of: "entrada",
            sub_kind_of: e[:sub_kind],
            amount: e[:amount],
            payment_date: Date.new(year, month, e[:day]),
            description: "Entrada test"
          )
        end

        saidas_data.each do |s|
          movements << build_movement(
            kind_of: "saida",
            sub_kind_of: s[:sub_kind],
            amount: s[:amount],
            payment_date: Date.new(year, month, s[:day]),
            description: "Saída test"
          )
        end

        # Create generator and stub
        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        report = generator.call

        # Calculate expected values
        expected_entradas = entradas_data.sum { |e| e[:amount] }
        expected_saidas = saidas_data.sum { |s| s[:amount] }
        expected_saldo = expected_entradas - expected_saidas

        # Extract the month section
        month_label = format("%02d/%04d", month, year)
        month_section_start = report.index("## #{month_label}")
        expect(month_section_start).not_to be_nil,
          "Expected to find month section '## #{month_label}' in report"

        # Get the month section content (up to next ## or end)
        rest = report[month_section_start..]
        next_section = rest.index("\n## ", 1)
        month_section = next_section ? rest[0...next_section] : rest

        # Verify total de entradas
        formatted_entradas = FinancialReports::Formatter.format_currency(expected_entradas)
        expect(month_section).to include("Total de entradas: #{formatted_entradas}"),
          "Expected total entradas #{formatted_entradas} in month section for #{month_label}"

        # Verify total de saídas
        formatted_saidas = FinancialReports::Formatter.format_currency(expected_saidas)
        expect(month_section).to include("Total de saídas: #{formatted_saidas}"),
          "Expected total saídas #{formatted_saidas} in month section for #{month_label}"

        # Verify saldo
        if expected_saldo < 0
          formatted_saldo = "-#{FinancialReports::Formatter.format_currency(expected_saldo.abs)}"
        else
          formatted_saldo = FinancialReports::Formatter.format_currency(expected_saldo)
        end
        expect(month_section).to include("Saldo: #{formatted_saldo}"),
          "Expected saldo #{formatted_saldo} in month section for #{month_label}"
      end
    end
  end

  describe "Property 6: Resumo geral correto (totais globais e contagem de meses)" do
    # Feature: monthly-financial-summary, Property 6: Resumo geral correto (totais globais e contagem de meses)
    # **Validates: Requirements 6.2, 6.3**
    #
    # For any set of movements, the general summary SHALL display: total entradas
    # equal to sum of all entradas across all months, total saídas equal to sum of
    # absolute values of all saídas, saldo geral equal to the difference, and month
    # count equal to the number of distinct year/month pairs with at least one movement.
    it "displays correct general summary with global totals and month count" do
      property_of {
        # Generate movements across multiple months (1 to 4 distinct months)
        num_months = range(1, 4)

        all_movements_data = []
        month_keys = []

        num_months.times do
          year = range(2020, 2025)
          month = range(1, 12)
          # Ensure distinct months
          while month_keys.include?([year, month])
            year = range(2020, 2025)
            month = range(1, 12)
          end
          month_keys << [year, month]
          max_day = Date.new(year, month, -1).day

          # Each month has between 1 and 4 movements (mix of entradas and saídas)
          num_entradas = range(0, 3)
          num_saidas = range(0, 3)
          # Ensure at least one movement per month
          num_entradas = 1 if num_entradas == 0 && num_saidas == 0

          num_entradas.times do
            cents = range(1, 999_999)
            amount = BigDecimal(cents.to_s) / BigDecimal("100")
            day = range(1, max_day)
            sub_kind = ENTRADA_SUB_KINDS.sample
            all_movements_data << { kind: "entrada", sub_kind: sub_kind, amount: amount, year: year, month: month, day: day }
          end

          num_saidas.times do
            cents = range(1, 999_999)
            amount = BigDecimal(cents.to_s) / BigDecimal("100")
            day = range(1, max_day)
            sub_kind = SAIDA_SUB_KINDS.sample
            all_movements_data << { kind: "saida", sub_kind: sub_kind, amount: amount, year: year, month: month, day: day }
          end
        end

        [num_months, all_movements_data]
      }.check(100) do |expected_month_count, all_movements_data|
        # Build mock movements
        movements = all_movements_data.map do |m|
          build_movement(
            kind_of: m[:kind],
            sub_kind_of: m[:sub_kind],
            amount: m[:amount],
            payment_date: Date.new(m[:year], m[:month], m[:day]),
            description: "Test movement"
          )
        end

        # Create generator and stub
        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        report = generator.call

        # Calculate expected values
        expected_total_entradas = all_movements_data
          .select { |m| m[:kind] == "entrada" }
          .sum { |m| m[:amount] }
        expected_total_saidas = all_movements_data
          .select { |m| m[:kind] == "saida" }
          .sum { |m| m[:amount] }
        expected_saldo_geral = expected_total_entradas - expected_total_saidas

        # Extract the Resumo Geral section
        resumo_start = report.index("## Resumo Geral")
        expect(resumo_start).not_to be_nil,
          "Expected to find '## Resumo Geral' section in report"
        resumo_section = report[resumo_start..]

        # Verify total de entradas
        formatted_entradas = FinancialReports::Formatter.format_currency(expected_total_entradas)
        expect(resumo_section).to include("Total de entradas | #{formatted_entradas}"),
          "Expected total entradas #{formatted_entradas} in Resumo Geral"

        # Verify total de saídas
        formatted_saidas = FinancialReports::Formatter.format_currency(expected_total_saidas)
        expect(resumo_section).to include("Total de saídas | #{formatted_saidas}"),
          "Expected total saídas #{formatted_saidas} in Resumo Geral"

        # Verify saldo geral
        if expected_saldo_geral < 0
          formatted_saldo = "-#{FinancialReports::Formatter.format_currency(expected_saldo_geral.abs)}"
        else
          formatted_saldo = FinancialReports::Formatter.format_currency(expected_saldo_geral)
        end
        expect(resumo_section).to include("Saldo geral | #{formatted_saldo}"),
          "Expected saldo geral #{formatted_saldo} in Resumo Geral"

        # Verify month count
        expect(resumo_section).to include("Meses com movimentações | #{expected_month_count}"),
          "Expected month count #{expected_month_count} in Resumo Geral"
      end
    end
  end

  describe "Property 8: Estrutura Markdown válida (tabelas, separadores e espaçamento)" do
    # Feature: monthly-financial-summary, Property 8: Estrutura Markdown válida (tabelas, separadores e espaçamento)
    # **Validates: Requirements 7.4, 7.5, 7.7**
    #
    # For any report generated with at least one movement, all tables SHALL contain
    # a header line, a separator line with alignment markers (`:---` for text, `---:` for numbers),
    # and data lines with the same number of columns. Horizontal separators (`---`) SHALL appear
    # between different month sections but NOT before the general summary section.

    # Helper to extract all Markdown tables from a report string.
    # A table is a sequence of consecutive lines that start and end with `|`.
    def extract_tables(report)
      lines = report.split("\n")
      tables = []
      current_table = []

      lines.each do |line|
        if line.strip.start_with?("|") && line.strip.end_with?("|")
          current_table << line
        else
          if current_table.size >= 2
            tables << current_table.dup
          end
          current_table = []
        end
      end

      # Don't forget the last table if the report ends with one
      tables << current_table.dup if current_table.size >= 2

      tables
    end

    # Count the number of columns in a table line
    def column_count(line)
      line.strip.split("|").size - 2
    end

    it "tables have header, separator with alignment markers, and consistent column count" do
      property_of {
        # Generate between 1 and 4 distinct months
        num_months = range(1, 4)
        all_movements_data = []
        month_keys = []

        num_months.times do
          year = range(2020, 2025)
          month = range(1, 12)
          while month_keys.include?([year, month])
            year = range(2020, 2025)
            month = range(1, 12)
          end
          month_keys << [year, month]
          max_day = Date.new(year, month, -1).day

          # Generate between 1 and 5 movements per month (mix of entradas and saidas)
          num_movements = range(1, 5)
          num_movements.times do
            is_entrada = boolean
            day = range(1, max_day)
            cents = range(1, 999_999)

            if is_entrada
              amount = BigDecimal(cents.to_s) / BigDecimal("100")
              sub_kind = ENTRADA_SUB_KINDS.sample
              kind = "entrada"
            else
              amount = BigDecimal(cents.to_s) / BigDecimal("100")
              sub_kind = SAIDA_SUB_KINDS.sample
              kind = "saida"
            end

            description = sized(range(1, 60)) { string(:alpha) }
            all_movements_data << { kind: kind, sub_kind: sub_kind, amount: amount, year: year, month: month, day: day, description: description }
          end
        end

        all_movements_data
      }.check(100) do |all_movements_data|
        # Build mock movements
        movements = all_movements_data.map do |m|
          build_movement(
            kind_of: m[:kind],
            sub_kind_of: m[:sub_kind],
            amount: m[:amount],
            payment_date: Date.new(m[:year], m[:month], m[:day]),
            description: m[:description]
          )
        end

        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        report = generator.call
        tables = extract_tables(report)

        # There should be at least one table (movements tables + general summary table)
        expect(tables).not_to be_empty,
          "Expected at least one Markdown table in the report"

        tables.each_with_index do |table, table_idx|
          # 1. First line is a header (contains `|`)
          header_line = table[0]
          expect(header_line).to include("|"),
            "Table #{table_idx}: First line should be a header containing '|'"

          # 2. Second line is a separator with alignment markers
          separator_line = table[1]
          separator_cells = separator_line.strip.split("|").reject(&:empty?).map(&:strip)
          separator_cells.each do |cell|
            expect(cell).to match(/\A:?-{3,}:?\z/),
              "Table #{table_idx}: Separator cell '#{cell}' should match alignment pattern (:--- or ---:)"
          end

          # Verify alignment markers: `:---` for text columns, `---:` for number columns
          has_left_align = separator_cells.any? { |c| c.match?(/\A:-{3,}\z/) }
          has_right_align = separator_cells.any? { |c| c.match?(/\A-{3,}:\z/) }
          expect(has_left_align || has_right_align).to be(true),
            "Table #{table_idx}: Separator should have at least one alignment marker (:--- or ---:)"

          # 3. All data lines have the same number of columns as the header
          header_cols = column_count(header_line)
          table[2..].each_with_index do |data_line, line_idx|
            data_cols = column_count(data_line)
            expect(data_cols).to eq(header_cols),
              "Table #{table_idx}, data line #{line_idx}: Expected #{header_cols} columns, got #{data_cols}.\n" \
              "Header: #{header_line}\nData line: #{data_line}"
          end
        end
      end
    end

    it "horizontal separators appear between month sections but NOT before the general summary" do
      property_of {
        # Generate between 2 and 4 distinct months to ensure separators are needed
        num_months = range(2, 4)
        all_movements_data = []
        month_keys = []

        num_months.times do
          year = range(2020, 2025)
          month = range(1, 12)
          while month_keys.include?([year, month])
            year = range(2020, 2025)
            month = range(1, 12)
          end
          month_keys << [year, month]
          max_day = Date.new(year, month, -1).day

          # At least one movement per month
          num_movements = range(1, 3)
          num_movements.times do
            is_entrada = boolean
            day = range(1, max_day)
            cents = range(1, 999_999)

            if is_entrada
              amount = BigDecimal(cents.to_s) / BigDecimal("100")
              sub_kind = ENTRADA_SUB_KINDS.sample
              kind = "entrada"
            else
              amount = BigDecimal(cents.to_s) / BigDecimal("100")
              sub_kind = SAIDA_SUB_KINDS.sample
              kind = "saida"
            end

            description = sized(range(1, 30)) { string(:alpha) }
            all_movements_data << { kind: kind, sub_kind: sub_kind, amount: amount, year: year, month: month, day: day, description: description }
          end
        end

        [num_months, all_movements_data]
      }.check(100) do |num_months, all_movements_data|
        # Build mock movements
        movements = all_movements_data.map do |m|
          build_movement(
            kind_of: m[:kind],
            sub_kind_of: m[:sub_kind],
            amount: m[:amount],
            payment_date: Date.new(m[:year], m[:month], m[:day]),
            description: m[:description]
          )
        end

        generator = described_class.new
        allow(generator).to receive(:fetch_movements).and_return(movements)
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        report = generator.call
        lines = report.split("\n")

        # Find all horizontal separator lines (standalone `---` lines, not table separators)
        # Table separators contain `|`, horizontal separators are just `---`
        separator_indices = lines.each_with_index
          .select { |line, _| line.strip == "---" }
          .map { |_, idx| idx }

        # With N months, there should be exactly N-1 separators between month sections
        expected_separators = num_months - 1
        expect(separator_indices.size).to eq(expected_separators),
          "Expected #{expected_separators} horizontal separators for #{num_months} months, got #{separator_indices.size}"

        # Verify no separator appears immediately before "## Resumo Geral"
        resumo_geral_idx = lines.index { |line| line.strip == "## Resumo Geral" }
        expect(resumo_geral_idx).not_to be_nil,
          "Expected to find '## Resumo Geral' section in the report"

        # Check that no `---` separator appears between the last month section and Resumo Geral
        if separator_indices.any?
          separator_indices.each do |sep_idx|
            # Lines between this separator and Resumo Geral
            lines_between = lines[(sep_idx + 1)...resumo_geral_idx]
            next unless lines_between

            # If there's no month header (## MM/YYYY) between this separator and Resumo Geral,
            # then this separator is incorrectly placed before Resumo Geral
            has_month_content_after = lines_between.any? { |l| l.strip.match?(/\A## \d{2}\/\d{4}\z/) }
            unless has_month_content_after
              fail "Found horizontal separator (---) at line #{sep_idx} that appears before '## Resumo Geral' without a month section in between"
            end
          end
        end
      end
    end
  end

  # ============================================================================
  # Unit Tests - Cenários específicos do gerador (Task 4.1)
  # ============================================================================

  describe "Unit Tests: cenários específicos do gerador" do
    let(:generator) { described_class.new }

    before do
      allow(Date).to receive(:current).and_return(Date.new(2024, 3, 20))
    end

    describe ".call retorna String (Req 8.1)" do
      it "retorna uma instância de String" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("500.00"),
            payment_date: Date.new(2024, 1, 10),
            description: "Dízimo membro"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        result = generator.call

        expect(result).to be_a(String)
      end

      it ".call class method delega para new.call e retorna String" do
        movements = [
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("200.00"),
            payment_date: Date.new(2024, 2, 5),
            description: "Material de limpeza"
          )
        ]

        allow_any_instance_of(described_class).to receive(:fetch_movements).and_return(movements)
        result = described_class.call

        expect(result).to be_a(String)
      end
    end

    describe "Cabeçalho com título e data de geração (Req 7.1)" do
      it "contém cabeçalho nível 1 com título 'Resumo Financeiro Mensal'" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("100.00"),
            payment_date: Date.new(2024, 1, 15),
            description: "Oferta dominical"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to include("# Resumo Financeiro Mensal")
      end

      it "contém data de geração formatada como dd/mm/aaaa" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("100.00"),
            payment_date: Date.new(2024, 1, 15),
            description: "Oferta dominical"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        # Date.current is stubbed to 2024-03-20, formatted as 20/03/2024
        expect(report).to include("Data de geração: 20/03/2024")
      end

      it "cabeçalho aparece no início do relatório" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("300.00"),
            payment_date: Date.new(2024, 2, 10),
            description: "Dízimo"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to start_with("# Resumo Financeiro Mensal\n\nData de geração: 20/03/2024")
      end
    end

    describe "Cabeçalhos nível 2 para meses e resumo geral (Req 7.2)" do
      it "usa cabeçalho nível 2 (##) para cada mês no formato MM/AAAA" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("1000.00"),
            payment_date: Date.new(2024, 1, 5),
            description: "Dízimo janeiro"
          ),
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("200.00"),
            payment_date: Date.new(2024, 3, 12),
            description: "Compra março"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to include("## 01/2024")
        expect(report).to include("## 03/2024")
      end

      it "usa cabeçalho nível 2 (##) para a seção Resumo Geral" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("500.00"),
            payment_date: Date.new(2024, 6, 1),
            description: "Oferta"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to include("## Resumo Geral")
      end

      it "meses com um dígito usam zero à esquerda (ex: 01/2024)" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("100.00"),
            payment_date: Date.new(2024, 1, 10),
            description: "Janeiro"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to include("## 01/2024")
        expect(report).not_to include("## 1/2024")
      end
    end

    describe "Cabeçalhos nível 3 para Entradas/Saídas (Req 7.3)" do
      it "usa cabeçalho nível 3 (###) para subseção Entradas" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("800.00"),
            payment_date: Date.new(2024, 4, 10),
            description: "Dízimo abril"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to include("### Entradas")
      end

      it "usa cabeçalho nível 3 (###) para subseção Saídas" do
        movements = [
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("150.00"),
            payment_date: Date.new(2024, 4, 15),
            description: "Compra material"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).to include("### Saídas")
      end

      it "Entradas e Saídas aparecem dentro da seção do mês" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("300.00"),
            payment_date: Date.new(2024, 5, 1),
            description: "Oferta maio"
          ),
          build_movement(
            kind_of: "saida",
            sub_kind_of: "outros_gastos",
            amount: BigDecimal("100.00"),
            payment_date: Date.new(2024, 5, 20),
            description: "Gastos diversos"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        # Extract the month section for 05/2024
        month_start = report.index("## 05/2024")
        expect(month_start).not_to be_nil

        rest = report[month_start..]
        next_section = rest.index("\n## ", 1)
        month_section = next_section ? rest[0...next_section] : rest

        expect(month_section).to include("### Entradas")
        expect(month_section).to include("### Saídas")
      end
    end

    describe "Codificação UTF-8 com LF (Req 7.6)" do
      it "relatório tem encoding UTF-8" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("1500.00"),
            payment_date: Date.new(2024, 7, 10),
            description: "Dízimo julho"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report.encoding).to eq(Encoding::UTF_8)
      end

      it "usa apenas LF (\\n) como quebra de linha, sem CRLF (\\r\\n)" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("250.00"),
            payment_date: Date.new(2024, 8, 5),
            description: "Oferta agosto"
          ),
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("80.00"),
            payment_date: Date.new(2024, 8, 15),
            description: "Compra"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        expect(report).not_to include("\r\n")
        expect(report).not_to include("\r")
        expect(report).to include("\n")
      end
    end

    describe "Uso do Formatter para formatação (Req 8.3)" do
      it "usa Formatter.format_currency para valores monetários" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("1234.56"),
            payment_date: Date.new(2024, 9, 10),
            description: "Dízimo setembro"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        # Formatter.format_currency(1234.56) => "R$ 1.234,56"
        expect(report).to include("R$ 1.234,56")
      end

      it "usa Formatter.format_date para datas nas tabelas" do
        payment_date = Date.new(2024, 10, 7)
        movements = [
          build_movement(
            kind_of: "saida",
            sub_kind_of: "outros_gastos",
            amount: BigDecimal("99.90"),
            payment_date: payment_date,
            description: "Gasto outubro"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        # Formatter.format_date(Date.new(2024, 10, 7)) => "07/10/2024"
        expected_date = FinancialReports::Formatter.format_date(payment_date)
        expect(report).to include(expected_date)
        expect(report).to include("07/10/2024")
      end

      it "usa Formatter.format_date para a data de geração no cabeçalho" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("50.00"),
            payment_date: Date.new(2024, 11, 1),
            description: "Oferta"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        # Date.current is stubbed to 2024-03-20
        expected_generation_date = FinancialReports::Formatter.format_date(Date.new(2024, 3, 20))
        expect(report).to include("Data de geração: #{expected_generation_date}")
      end

      it "formata totais mensais usando Formatter.format_currency" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("5000.00"),
            payment_date: Date.new(2024, 12, 1),
            description: "Dízimo dezembro"
          ),
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("2500.50"),
            payment_date: Date.new(2024, 12, 15),
            description: "Oferta dezembro"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)
        report = generator.call

        # Total entradas: 5000.00 + 2500.50 = 7500.50 => "R$ 7.500,50"
        expected_total = FinancialReports::Formatter.format_currency(BigDecimal("7500.50"))
        expect(report).to include("Total de entradas: #{expected_total}")
      end
    end
  end

  # ============================================================================
  # Unit Tests - Edge Cases (Task 4.2)
  # ============================================================================

  describe "Edge cases" do
    let(:generator) { described_class.new }

    before do
      allow(Date).to receive(:current).and_return(Date.new(2024, 6, 15))
    end

    describe "Banco vazio gera relatório com resumo zerado (Req 1.3)" do
      it "gera relatório com cabeçalho e resumo geral zerado quando não há movimentações" do
        allow(generator).to receive(:fetch_movements).and_return([])

        report = generator.call

        # Should have header
        expect(report).to include("# Resumo Financeiro Mensal")
        expect(report).to include("Data de geração: 15/06/2024")

        # Should have Resumo Geral with all zeros
        expect(report).to include("## Resumo Geral")
        expect(report).to include("| Total de entradas | R$ 0,00 |")
        expect(report).to include("| Total de saídas | R$ 0,00 |")
        expect(report).to include("| Saldo geral | R$ 0,00 |")
        expect(report).to include("| Meses com movimentações | 0 |")

        # Should NOT have any month sections
        expect(report).not_to match(/^## \d{2}\/\d{4}$/)
      end
    end

    describe "Mês com apenas entradas — saídas com total R$ 0,00 (Req 2.4, 4.5)" do
      it "exibe seção de saídas com tabela vazia e total R$ 0,00" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("500.00"),
            payment_date: Date.new(2024, 3, 10),
            description: "Dízimo membro A"
          ),
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("200.00"),
            payment_date: Date.new(2024, 3, 15),
            description: "Oferta culto"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)

        report = generator.call

        # Should have Entradas section with data
        expect(report).to include("### Entradas")
        expect(report).to include("| 10/03/2024 | Dízimo | R$ 500,00 | Dízimo membro A |")
        expect(report).to include("| 15/03/2024 | Oferta | R$ 200,00 | Oferta culto |")
        expect(report).to include("**Total de entradas:** R$ 700,00")

        # Should have Saídas section with empty table header and total R$ 0,00
        expect(report).to include("### Saídas")
        expect(report).to include("**Total de saídas:** R$ 0,00")

        # Saídas section should have table header but no data rows
        saidas_section = report.split("### Saídas").last.split("**Total de saídas:**").first
        expect(saidas_section).to include("| Data | Categoria | Valor | Descrição |")
        expect(saidas_section).to include("| :--- | :--- | ---: | :--- |")
        data_rows = saidas_section.lines.select { |l| l.match?(/^\| \d{2}\/\d{2}\/\d{4}/) }
        expect(data_rows).to be_empty
      end
    end

    describe "Mês com apenas saídas — subseção Entradas omitida (Req 3.5)" do
      it "omite a subseção Entradas quando não há entradas no mês" do
        movements = [
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("300.00"),
            payment_date: Date.new(2024, 5, 5),
            description: "Material limpeza"
          ),
          build_movement(
            kind_of: "saida",
            sub_kind_of: "outros_gastos",
            amount: BigDecimal("150.00"),
            payment_date: Date.new(2024, 5, 20),
            description: "Manutenção"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)

        report = generator.call

        # Should have the month section
        expect(report).to include("## 05/2024")

        # Should NOT have Entradas subsection
        expect(report).not_to include("### Entradas")

        # Should have Saídas section with data
        expect(report).to include("### Saídas")
        expect(report).to include("| 05/05/2024 | Compra | R$ 300,00 | Material limpeza |")
        expect(report).to include("| 20/05/2024 | Outros gastos | R$ 150,00 | Manutenção |")
        expect(report).to include("**Total de saídas:** R$ 450,00")

        # Monthly summary should show entradas as R$ 0,00 and negative saldo
        expect(report).to include("- Total de entradas: R$ 0,00")
        expect(report).to include("- Saldo: -R$ 450,00")
      end
    end

    describe "Saldo negativo com formato '-R$ X.XXX,XX' (Req 5.3)" do
      it "exibe saldo negativo no formato correto quando saídas > entradas" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("1000.00"),
            payment_date: Date.new(2024, 2, 10),
            description: "Oferta"
          ),
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("2500.50"),
            payment_date: Date.new(2024, 2, 15),
            description: "Compra grande"
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)

        report = generator.call

        # Saldo = 1000.00 - 2500.50 = -1500.50
        expect(report).to include("- Saldo: -R$ 1.500,50")

        # Resumo Geral should also show negative saldo
        expect(report).to include("| Saldo geral | -R$ 1.500,50 |")
      end
    end

    describe "Descrição nil tratada como string vazia" do
      it "exibe campo de descrição vazio quando description é nil" do
        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "dízimo",
            amount: BigDecimal("100.00"),
            payment_date: Date.new(2024, 4, 10),
            description: nil
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)

        report = generator.call

        # The row should have an empty description field
        expect(report).to include("| 10/04/2024 | Dízimo | R$ 100,00 |  |")
      end
    end

    describe "Descrição com exatamente 50 caracteres (não truncada)" do
      it "exibe descrição completa sem truncamento" do
        desc_50 = "A" * 50 # exactly 50 characters

        movements = [
          build_movement(
            kind_of: "entrada",
            sub_kind_of: "oferta",
            amount: BigDecimal("250.00"),
            payment_date: Date.new(2024, 7, 1),
            description: desc_50
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)

        report = generator.call

        # Full 50-char description should appear without truncation
        expect(report).to include("| #{desc_50} |")
        expect(report).not_to include("#{desc_50}...")
      end
    end

    describe "Descrição com 51 caracteres (truncada com '...')" do
      it "trunca descrição para 50 caracteres + '...'" do
        desc_51 = "B" * 51 # 51 characters

        movements = [
          build_movement(
            kind_of: "saida",
            sub_kind_of: "compra",
            amount: BigDecimal("75.00"),
            payment_date: Date.new(2024, 8, 20),
            description: desc_51
          )
        ]

        allow(generator).to receive(:fetch_movements).and_return(movements)

        report = generator.call

        # Should be truncated to first 50 chars + "..."
        expected_truncated = "B" * 50 + "..."
        expect(expected_truncated.length).to eq(53)
        expect(report).to include("| #{expected_truncated} |")
        # Full 51-char description should NOT appear
        expect(report).not_to include("| #{desc_51} |")
      end
    end
  end
end
