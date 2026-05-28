# frozen_string_literal: true

require "spec_helper"
require "rantly"
require "rantly/rspec_extensions"
require "bigdecimal"
require "ostruct"
require "date"
require "active_support/core_ext/object/blank"
require_relative "../../../lib/financial_reports/formatter"

RSpec.describe FinancialReports::Formatter do
  describe ".format_currency - property tests" do
    # Feature: financial-reports, Property 1: Formatação de moeda brasileira (round-trip de valor)
    # **Validates: Requirements 2.6, 3.5**
    #
    # For any non-negative decimal value with up to 2 decimal places,
    # the format_currency function SHALL produce a string in the format R$ X.XXX,XX
    # where the reverse parsing (removing "R$ ", replacing "." with "" and "," with ".")
    # returns the original value.
    it "round-trips any non-negative decimal value with up to 2 decimal places" do
      property_of {
        # Generate non-negative integers for the "cents" representation
        # to ensure exactly 2 decimal places without floating point issues.
        # Range: 1 to 99_999_999_99 (up to ~999,999,999.99)
        cents = range(1, 9_999_999_999)
        # Convert to a BigDecimal with 2 decimal places
        BigDecimal(cents.to_s) / BigDecimal("100")
      }.check(200) do |value|
        formatted = FinancialReports::Formatter.format_currency(value)

        # Verify format matches R$ X.XXX,XX pattern
        expect(formatted).to match(/\AR\$ [\d.]+(,\d{2})\z/),
          "Expected '#{formatted}' to match R$ X.XXX,XX format for value #{value}"

        # Reverse parse: remove "R$ ", replace "." with "", replace "," with "."
        numeric_str = formatted
          .sub("R$ ", "")
          .gsub(".", "")
          .sub(",", ".")

        parsed_value = BigDecimal(numeric_str)

        expect(parsed_value).to eq(value),
          "Round-trip failed: #{value} -> '#{formatted}' -> #{parsed_value}"
      end
    end
  end

  # Unit tests - Task 1.3
  # Validates: Requirements 2.6, 2.9, 3.5

  describe ".format_currency - unit tests" do
    context "with zero values" do
      it "returns 'R$ 0,00' for zero" do
        expect(described_class.format_currency(0)).to eq("R$ 0,00")
      end

      it "returns 'R$ 0,00' for BigDecimal zero" do
        expect(described_class.format_currency(BigDecimal("0"))).to eq("R$ 0,00")
      end

      it "returns 'R$ 0,00' for nil" do
        expect(described_class.format_currency(nil)).to eq("R$ 0,00")
      end
    end

    context "with integer values" do
      it "formats integer 1 as 'R$ 1,00'" do
        expect(described_class.format_currency(1)).to eq("R$ 1,00")
      end

      it "formats integer 100 as 'R$ 100,00'" do
        expect(described_class.format_currency(100)).to eq("R$ 100,00")
      end

      it "formats integer 1000 with dot separator as 'R$ 1.000,00'" do
        expect(described_class.format_currency(1000)).to eq("R$ 1.000,00")
      end
    end

    context "with decimal values" do
      it "formats 9.99 as 'R$ 9,99'" do
        expect(described_class.format_currency(BigDecimal("9.99"))).to eq("R$ 9,99")
      end

      it "formats 1234.56 as 'R$ 1.234,56'" do
        expect(described_class.format_currency(BigDecimal("1234.56"))).to eq("R$ 1.234,56")
      end

      it "formats 0.01 as 'R$ 0,01'" do
        expect(described_class.format_currency(BigDecimal("0.01"))).to eq("R$ 0,01")
      end

      it "formats 0.10 as 'R$ 0,10'" do
        expect(described_class.format_currency(BigDecimal("0.10"))).to eq("R$ 0,10")
      end
    end

    context "with large values" do
      it "formats 1_000_000 as 'R$ 1.000.000,00'" do
        expect(described_class.format_currency(1_000_000)).to eq("R$ 1.000.000,00")
      end

      it "formats 999_999_999.99 with correct dot separators" do
        expect(described_class.format_currency(BigDecimal("999999999.99"))).to eq("R$ 999.999.999,99")
      end

      it "formats 12_345_678.90 correctly" do
        expect(described_class.format_currency(BigDecimal("12345678.90"))).to eq("R$ 12.345.678,90")
      end
    end
  end

  describe ".format_date - unit tests" do
    context "with valid dates" do
      it "formats a date as dd/mm/yyyy" do
        date = Date.new(2024, 3, 15)
        expect(described_class.format_date(date)).to eq("15/03/2024")
      end

      it "formats first day of year correctly" do
        date = Date.new(2023, 1, 1)
        expect(described_class.format_date(date)).to eq("01/01/2023")
      end

      it "formats last day of year correctly" do
        date = Date.new(2023, 12, 31)
        expect(described_class.format_date(date)).to eq("31/12/2023")
      end

      it "pads single-digit day and month with zero" do
        date = Date.new(2020, 5, 7)
        expect(described_class.format_date(date)).to eq("07/05/2020")
      end
    end

    context "with nil" do
      it "returns nil for nil input" do
        expect(described_class.format_date(nil)).to be_nil
      end
    end
  end

  describe ".full_name - unit tests" do
    context "with last_name present" do
      it "returns first_name and last_name separated by space" do
        user = OpenStruct.new(first_name: "João", last_name: "Silva")
        expect(described_class.full_name(user)).to eq("João Silva")
      end

      it "handles multi-word last names" do
        user = OpenStruct.new(first_name: "Maria", last_name: "da Costa")
        expect(described_class.full_name(user)).to eq("Maria da Costa")
      end
    end

    context "with last_name empty" do
      it "returns only first_name when last_name is empty string" do
        user = OpenStruct.new(first_name: "Pedro", last_name: "")
        expect(described_class.full_name(user)).to eq("Pedro")
      end

      it "returns only first_name when last_name is whitespace" do
        user = OpenStruct.new(first_name: "Ana", last_name: "   ")
        expect(described_class.full_name(user)).to eq("Ana")
      end
    end

    context "with last_name nil" do
      it "returns only first_name when last_name is nil" do
        user = OpenStruct.new(first_name: "Carlos", last_name: nil)
        expect(described_class.full_name(user)).to eq("Carlos")
      end
    end
  end
end
