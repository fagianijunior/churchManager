# frozen_string_literal: true

require "spec_helper"
require "rantly"
require "rantly/rspec_extensions"
require "bigdecimal"
require "ostruct"
require "date"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/date/calculations"
require_relative "../../../lib/financial_reports/formatter"
require_relative "../../../lib/financial_reports/tithes_report_generator"
require_relative "../../../lib/financial_reports/salaries_report_generator"

# Stub ActiveRecord models for tests that don't load Rails
class Movement; end unless defined?(Movement)
class Administration; end unless defined?(Administration)

RSpec.describe "Markdown Format Properties" do
  # Feature: financial-reports, Property 9: Tabelas Markdown com sintaxe válida
  # **Validates: Requirements 4.2**
  #
  # For any set of input data, the generated tables SHALL contain a header line,
  # a separator line with alignment markers (`:---` for text, `---:` for numbers),
  # and data lines with the same number of columns as the header.
  describe "Property 9: Tabelas Markdown com sintaxe válida" do
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

    # Count the number of columns in a table line (number of `|` separators minus 1,
    # since lines start and end with `|`)
    def column_count(line)
      line.strip.split("|").size - 2
    end

    context "TithesReportGenerator" do
      it "generates tables with valid header, separator with alignment markers, and consistent column count" do
        property_of {
          # Generate between 1 and 5 members, each with 1 to 8 tithes
          num_members = range(1, 5)

          all_tithes = []

          num_members.times do |i|
            user = OpenStruct.new(
              id: i + 1,
              first_name: sized(range(3, 8)) { string(:alpha) }.capitalize,
              last_name: sized(range(3, 8)) { string(:alpha) }.capitalize
            )

            num_tithes = range(1, 8)
            num_tithes.times do |j|
              cents = range(1, 999_999)
              amount = BigDecimal(cents.to_s) / BigDecimal("100")
              date = Date.new(2020 + range(0, 4), range(1, 12), range(1, 28))

              tithe = OpenStruct.new(
                user_id: user.id,
                user: user,
                amount: amount,
                payment_date: date,
                description: sized(range(0, 20)) { string(:alpha) }
              )
              all_tithes << tithe
            end
          end

          all_tithes
        }.check(100) do |all_tithes|
          generator = FinancialReports::TithesReportGenerator.new
          allow(generator).to receive(:fetch_tithes).and_return(all_tithes)
          allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

          report = generator.call
          tables = extract_tables(report)

          # There should be at least one table (one per member)
          expect(tables).not_to be_empty,
            "Expected at least one Markdown table in the tithes report"

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

            # Verify alignment markers: `:---` for text, `---:` for numbers
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
    end

    context "SalariesReportGenerator" do
      it "generates tables with valid header, separator with alignment markers, and consistent column count" do
        property_of {
          # Generate between 1 and 6 administration records
          num_records = range(1, 6)

          administrations = Array.new(num_records) do |i|
            user = OpenStruct.new(
              id: i + 1,
              first_name: sized(range(3, 8)) { string(:alpha) }.capitalize,
              last_name: sized(range(3, 8)) { string(:alpha) }.capitalize
            )

            occupation = OpenStruct.new(
              title: sized(range(3, 12)) { string(:alpha) }.capitalize
            )

            salary = BigDecimal(range(1000, 5_000_000).to_s) / BigDecimal("100")
            has_payment_day = boolean
            payment_day = has_payment_day ? range(1, 31) : nil
            start_date = Date.new(range(2015, 2023), range(1, 12), range(1, 28))
            has_end_date = boolean
            end_date = has_end_date ? Date.new(range(2020, 2024), range(1, 12), range(1, 28)) : nil

            OpenStruct.new(
              id: i + 1,
              user: user,
              user_id: user.id,
              occupation: occupation,
              occupation_id: i + 1,
              salary: salary,
              payment_day: payment_day,
              start_date: start_date,
              end_date: end_date
            )
          end

          administrations
        }.check(100) do |administrations|
          generator = FinancialReports::SalariesReportGenerator.new
          allow(generator).to receive(:fetch_administrations).and_return(administrations)
          allow(Date).to receive(:today).and_return(Date.new(2024, 1, 15))

          report = generator.call
          tables = extract_tables(report)

          # There should be at least one table (one per employee + summary)
          expect(tables).not_to be_empty,
            "Expected at least one Markdown table in the salaries report"

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

            # Verify alignment markers exist
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
    end
  end
end
