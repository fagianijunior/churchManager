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

# Stub Movement class for tests that don't load Rails
class Movement; end unless defined?(Movement)

RSpec.describe FinancialReports::TithesReportGenerator do
  describe "Property 2: Agregação correta de dízimos por membro" do
    # Feature: financial-reports, Property 2: Agregação correta de dízimos por membro
    # **Validates: Requirements 2.4**
    #
    # For any set of tithe movements associated with a member, the report SHALL
    # display the correct count and the correct total value (sum of amounts) for
    # that member.
    it "displays correct count and total value for each member's tithes" do
      property_of {
        # Generate a random number of tithes for a single member (1 to 20)
        tithe_count = range(1, 20)

        # Generate random amounts as cents to avoid floating point issues
        amounts = Array.new(tithe_count) { range(1, 1_000_000) }
          .map { |cents| BigDecimal(cents.to_s) / BigDecimal("100") }

        # Generate a random user name
        first_name = sized(range(3, 10)) { string(:alpha) }.capitalize
        last_name = sized(range(3, 10)) { string(:alpha) }.capitalize

        [first_name, last_name, amounts]
      }.check(100) do |first_name, last_name, amounts|
        # Build mock user
        user = OpenStruct.new(
          first_name: first_name,
          last_name: last_name
        )

        # Build mock tithe movements
        user_id = rand(1..1000)
        tithes = amounts.each_with_index.map do |amount, i|
          OpenStruct.new(
            user_id: user_id,
            user: user,
            amount: amount,
            payment_date: Date.new(2023, 1, 1) + i,
            description: "Dízimo #{i + 1}"
          )
        end

        # Create generator instance and stub the private fetch_tithes method
        generator = described_class.new
        allow(generator).to receive(:fetch_tithes).and_return(tithes)

        # Stub Date.current for the header
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        # Generate the report
        report = generator.call

        # Calculate expected values
        expected_count = amounts.size
        expected_total = amounts.sum

        # Verify the report contains the correct count
        expect(report).to include("**Quantidade de dízimos:** #{expected_count}"),
          "Expected report to show count #{expected_count} for member #{first_name} #{last_name}"

        # Verify the report contains the correct total formatted as currency
        expected_formatted_total = FinancialReports::Formatter.format_currency(expected_total)
        expect(report).to include("**Valor total:** #{expected_formatted_total}"),
          "Expected report to show total #{expected_formatted_total} for member #{first_name} #{last_name}"
      end
    end
  end

  describe "Property 5: Resumo geral de dízimos correto" do
    # Feature: financial-reports, Property 5: Resumo geral de dízimos correto
    # **Validates: Requirements 2.7**
    #
    # For any set of contributing members, the general summary SHALL display
    # the total number of contributing members equal to the number of distinct
    # members with at least one tithe, and the total value equal to the sum of
    # all tithes from all members.
    it "displays correct member count and total amount in the summary" do
      property_of {
        # Generate between 1 and 8 members
        num_members = range(1, 8)

        all_tithes = []

        num_members.times do |i|
          user = OpenStruct.new(
            id: i + 1,
            first_name: "Member#{i}",
            last_name: "Last#{i}"
          )

          # Each member has between 1 and 5 tithes
          num_tithes = range(1, 5)

          num_tithes.times do |j|
            # Generate amount as cents (1 to 999999) then convert to BigDecimal
            cents = range(1, 999_999)
            amount = BigDecimal(cents.to_s) / BigDecimal("100")
            date = Date.new(2020 + range(0, 4), range(1, 12), range(1, 28))

            tithe = OpenStruct.new(
              user_id: user.id,
              user: user,
              amount: amount,
              payment_date: date,
              description: "Tithe #{j}"
            )
            all_tithes << tithe
          end
        end

        [num_members, all_tithes]
      }.check(100) do |num_members, all_tithes|
        # Build the generator and stub the data fetching
        generator = described_class.new
        allow(generator).to receive(:fetch_tithes).and_return(all_tithes)

        # Stub Date.current for the header
        allow(Date).to receive(:current).and_return(Date.new(2024, 1, 15))

        # Generate the report
        report = generator.call

        # Calculate expected values
        expected_member_count = num_members
        expected_total = all_tithes.sum(&:amount)

        # Parse the summary section from the Markdown
        summary_section = report.split("## Resumo Geral").last

        # Extract member count
        member_count_match = summary_section.match(/\*\*Total de membros contribuintes:\*\*\s*(\d+)/)
        expect(member_count_match).not_to be_nil,
          "Could not find member count in summary section:\n#{summary_section}"
        actual_member_count = member_count_match[1].to_i

        expect(actual_member_count).to eq(expected_member_count),
          "Expected #{expected_member_count} contributing members, got #{actual_member_count}"

        # Extract total amount - parse the formatted currency back to a number
        total_match = summary_section.match(/\*\*Valor total de todos os dízimos:\*\*\s*R\$\s*([\d.,]+)/)
        expect(total_match).not_to be_nil,
          "Could not find total amount in summary section:\n#{summary_section}"

        # Parse Brazilian currency format back to BigDecimal
        amount_str = total_match[1].gsub(".", "").sub(",", ".")
        actual_total = BigDecimal(amount_str)

        expect(actual_total).to eq(expected_total),
          "Expected total R$ #{expected_total}, got R$ #{actual_total}"
      end
    end
  end

  # Unit tests - Task 2.6
  # Validates: Requirements 2.1, 2.2, 2.7, 2.8, 2.9, 1.7

  describe "#call - unit tests" do
    # Helper to build a mock Movement object
    def build_movement(user_id:, user: nil, payment_date:, amount:, description: "")
      OpenStruct.new(
        user_id: user_id,
        user: user,
        payment_date: payment_date,
        amount: amount,
        description: description
      )
    end

    # Helper to build a mock User object
    def build_user(first_name:, last_name:)
      OpenStruct.new(first_name: first_name, last_name: last_name)
    end

    before do
      allow(Date).to receive(:current).and_return(Date.new(2024, 6, 15))
    end

    context "com múltiplos membros e dízimos" do
      let(:user_ana) { build_user(first_name: "Ana", last_name: "Costa") }
      let(:user_bruno) { build_user(first_name: "Bruno", last_name: "Silva") }

      let(:tithes) do
        [
          build_movement(user_id: 1, user: user_ana, payment_date: Date.new(2024, 1, 10), amount: BigDecimal("100.00"), description: "Janeiro"),
          build_movement(user_id: 1, user: user_ana, payment_date: Date.new(2024, 2, 15), amount: BigDecimal("150.50"), description: "Fevereiro"),
          build_movement(user_id: 2, user: user_bruno, payment_date: Date.new(2024, 3, 5), amount: BigDecimal("200.00"), description: "Março"),
          build_movement(user_id: 2, user: user_bruno, payment_date: Date.new(2024, 1, 20), amount: BigDecimal("250.75"), description: "Janeiro")
        ]
      end

      before do
        generator_instance = nil
        allow(described_class).to receive(:new).and_wrap_original do |method|
          generator_instance = method.call
          allow(generator_instance).to receive(:fetch_tithes).and_return(tithes)
          generator_instance
        end
      end

      it "gera o cabeçalho com título e data de geração" do
        result = described_class.call
        expect(result).to include("# Relatório de Dízimos por Membro")
        expect(result).to include("**Data de geração:** 15/06/2024")
      end

      it "lista membros em ordem alfabética (Ana antes de Bruno)" do
        result = described_class.call
        ana_pos = result.index("## Ana Costa")
        bruno_pos = result.index("## Bruno Silva")
        expect(ana_pos).to be < bruno_pos
      end

      it "exibe quantidade e valor total corretos para cada membro" do
        result = described_class.call
        # Ana: 2 dízimos, R$ 250,50
        ana_section_start = result.index("## Ana Costa")
        bruno_section_start = result.index("## Bruno Silva")
        ana_section = result[ana_section_start...bruno_section_start]
        expect(ana_section).to include("**Quantidade de dízimos:** 2")
        expect(ana_section).to include("R$ 250,50")

        # Bruno: 2 dízimos, R$ 450,75
        resumo_start = result.index("## Resumo Geral")
        bruno_section = result[bruno_section_start...resumo_start]
        expect(bruno_section).to include("**Quantidade de dízimos:** 2")
        expect(bruno_section).to include("R$ 450,75")
      end

      it "gera tabela com colunas Data, Valor, Descrição" do
        result = described_class.call
        expect(result).to include("| Data | Valor | Descrição |")
        expect(result).to include("| :--- | ---: | :--- |")
      end

      it "lista dízimos individuais com data, valor e descrição" do
        result = described_class.call
        expect(result).to include("| 10/01/2024 | R$ 100,00 | Janeiro |")
        expect(result).to include("| 15/02/2024 | R$ 150,50 | Fevereiro |")
        expect(result).to include("| 05/03/2024 | R$ 200,00 | Março |")
      end

      it "ordena dízimos de cada membro cronologicamente" do
        result = described_class.call
        # Bruno's tithes: Jan 20 should come before Mar 5
        bruno_section_start = result.index("## Bruno Silva")
        bruno_section = result[bruno_section_start..]
        jan_pos = bruno_section.index("20/01/2024")
        mar_pos = bruno_section.index("05/03/2024")
        expect(jan_pos).to be < mar_pos
      end

      it "gera resumo geral com total de membros e valor total" do
        result = described_class.call
        expect(result).to include("## Resumo Geral")
        expect(result).to include("**Total de membros contribuintes:** 2")
        expect(result).to include("**Valor total de todos os dízimos:** R$ 701,25")
      end

      it "usa separadores horizontais entre seções" do
        result = described_class.call
        expect(result).to include("---")
      end
    end

    context "com dízimos sem user_id" do
      let(:user_maria) { build_user(first_name: "Maria", last_name: "Santos") }

      let(:tithes) do
        [
          build_movement(user_id: 1, user: user_maria, payment_date: Date.new(2024, 1, 10), amount: BigDecimal("100.00"), description: "Janeiro"),
          build_movement(user_id: nil, user: nil, payment_date: Date.new(2024, 2, 5), amount: BigDecimal("50.00"), description: "Anônimo 1"),
          build_movement(user_id: nil, user: nil, payment_date: Date.new(2024, 3, 10), amount: BigDecimal("75.25"), description: "Anônimo 2")
        ]
      end

      before do
        allow(described_class).to receive(:new).and_wrap_original do |method|
          instance = method.call
          allow(instance).to receive(:fetch_tithes).and_return(tithes)
          instance
        end
      end

      it "agrupa dízimos sem user_id em seção separada" do
        result = described_class.call
        expect(result).to include("## Dízimos sem membro identificado")
      end

      it "exibe quantidade e valor total dos dízimos órfãos" do
        result = described_class.call
        orphan_section_start = result.index("## Dízimos sem membro identificado")
        orphan_section = result[orphan_section_start..]
        expect(orphan_section).to include("**Quantidade de dízimos:** 2")
        expect(orphan_section).to include("R$ 125,25")
      end

      it "lista dízimos órfãos na tabela com dados corretos" do
        result = described_class.call
        expect(result).to include("| 05/02/2024 | R$ 50,00 | Anônimo 1 |")
        expect(result).to include("| 10/03/2024 | R$ 75,25 | Anônimo 2 |")
      end

      it "posiciona seção de órfãos após membros identificados" do
        result = described_class.call
        maria_pos = result.index("## Maria Santos")
        orphan_pos = result.index("## Dízimos sem membro identificado")
        expect(maria_pos).to be < orphan_pos
      end

      it "conta apenas membros identificados no resumo geral" do
        result = described_class.call
        expect(result).to include("**Total de membros contribuintes:** 1")
      end

      it "inclui todos os dízimos (incluindo órfãos) no valor total do resumo" do
        result = described_class.call
        expect(result).to include("**Valor total de todos os dízimos:** R$ 225,25")
      end
    end

    context "com membro com last_name vazio" do
      let(:user_no_lastname) { build_user(first_name: "Pedro", last_name: "") }
      let(:user_nil_lastname) { build_user(first_name: "Carlos", last_name: nil) }

      let(:tithes) do
        [
          build_movement(user_id: 1, user: user_no_lastname, payment_date: Date.new(2024, 1, 10), amount: BigDecimal("100.00"), description: "Dízimo"),
          build_movement(user_id: 2, user: user_nil_lastname, payment_date: Date.new(2024, 2, 15), amount: BigDecimal("200.00"), description: "Dízimo")
        ]
      end

      before do
        allow(described_class).to receive(:new).and_wrap_original do |method|
          instance = method.call
          allow(instance).to receive(:fetch_tithes).and_return(tithes)
          instance
        end
      end

      it "exibe apenas first_name quando last_name é vazio" do
        result = described_class.call
        expect(result).to include("## Pedro")
      end

      it "exibe apenas first_name quando last_name é nil" do
        result = described_class.call
        expect(result).to include("## Carlos")
      end

      it "ordena membros sem last_name corretamente entre os demais" do
        result = described_class.call
        carlos_pos = result.index("## Carlos")
        pedro_pos = result.index("## Pedro")
        # Carlos comes before Pedro alphabetically
        expect(carlos_pos).to be < pedro_pos
      end
    end

    context "com banco vazio (sem dízimos)" do
      let(:tithes) { [] }

      before do
        allow(described_class).to receive(:new).and_wrap_original do |method|
          instance = method.call
          allow(instance).to receive(:fetch_tithes).and_return(tithes)
          instance
        end
      end

      it "gera cabeçalho mesmo sem dados" do
        result = described_class.call
        expect(result).to include("# Relatório de Dízimos por Membro")
        expect(result).to include("**Data de geração:** 15/06/2024")
      end

      it "gera resumo com valores zerados" do
        result = described_class.call
        expect(result).to include("## Resumo Geral")
        expect(result).to include("**Total de membros contribuintes:** 0")
        expect(result).to include("**Valor total de todos os dízimos:** R$ 0,00")
      end

      it "não inclui seção de dízimos sem membro identificado" do
        result = described_class.call
        expect(result).not_to include("## Dízimos sem membro identificado")
      end

      it "não inclui tabelas de dízimos" do
        result = described_class.call
        expect(result).not_to include("| Data | Valor | Descrição |")
      end
    end
  end
end
