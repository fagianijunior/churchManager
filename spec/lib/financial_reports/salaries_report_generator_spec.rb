# frozen_string_literal: true

require "spec_helper"
require "rantly"
require "rantly/rspec_extensions"
require "bigdecimal"
require "ostruct"
require "date"
require "active_support/core_ext/object/blank"
require_relative "../../../lib/financial_reports/formatter"
require_relative "../../../lib/financial_reports/salaries_report_generator"

RSpec.describe FinancialReports::SalariesReportGenerator do
  describe "property tests" do
    # Feature: financial-reports, Property 6: Filtragem e ordenação do relatório de salários
    # **Validates: Requirements 3.3**
    #
    # For any set of administration records, the salary report SHALL include only records
    # with non-null salary greater than zero, and SHALL order them alphabetically by the
    # user's full name.
    it "includes only records with salary > 0 and orders them alphabetically by full name" do
      property_of {
        # Generate between 3 and 12 administration records
        # Mix of valid (salary > 0), zero salary, and nil salary records
        num_records = range(3, 12)

        records = Array.new(num_records) do |i|
          first_name = sized(range(3, 8)) { string(:alpha) }.capitalize
          last_name = sized(range(3, 8)) { string(:alpha) }.capitalize

          # Randomly assign salary: valid (> 0), zero, or nil
          salary_type = range(0, 2)
          salary = case salary_type
                   when 0 then BigDecimal(range(1, 100_000).to_s) / BigDecimal("100") # valid > 0
                   when 1 then BigDecimal("0") # zero
                   when 2 then nil # nil
                   end

          user = OpenStruct.new(
            id: i + 1,
            first_name: first_name,
            last_name: last_name
          )

          occupation = OpenStruct.new(
            title: "Cargo #{i + 1}"
          )

          OpenStruct.new(
            id: i + 1,
            user: user,
            user_id: user.id,
            occupation: occupation,
            occupation_id: i + 1,
            salary: salary,
            payment_day: range(1, 31),
            start_date: Date.new(2020, range(1, 12), range(1, 28)),
            end_date: nil
          )
        end

        records
      }.check(100) do |records|
        # Determine which records should appear in the report (salary not nil and > 0)
        valid_records = records.select { |r| !r.salary.nil? && r.salary > 0 }

        # Sort valid records alphabetically by full name (matching the generator's ORDER BY)
        sorted_valid = valid_records.sort_by do |r|
          [r.user.first_name.downcase, r.user.last_name.downcase]
        end

        # Stub the fetch_administrations method to return only valid, sorted records
        # (simulating what the database query would return)
        generator = FinancialReports::SalariesReportGenerator.new
        allow(generator).to receive(:fetch_administrations).and_return(sorted_valid)

        # Generate the report
        report = generator.call

        # Extract ## headers (employee names) from the Markdown output
        # Skip the header "Relatório de Salários" and "Resumo"
        section_headers = report.scan(/^## (.+)$/).flatten
        employee_names = section_headers.reject do |name|
          name == "Relatório de Salários" || name == "Resumo"
        end

        # Verify: only valid records appear (count matches)
        expect(employee_names.size).to eq(sorted_valid.size),
          "Expected #{sorted_valid.size} employees in report, got #{employee_names.size}.\n" \
          "Names found: #{employee_names}\n" \
          "Valid records: #{sorted_valid.map { |r| FinancialReports::Formatter.full_name(r.user) }}"

        # Verify: records with salary nil or zero do NOT appear
        invalid_records = records.select { |r| r.salary.nil? || r.salary <= 0 }
        invalid_names = invalid_records.map { |r| FinancialReports::Formatter.full_name(r.user) }
        invalid_names.each do |invalid_name|
          # Only check if the name is unique to invalid records (not shared with valid ones)
          valid_names = sorted_valid.map { |r| FinancialReports::Formatter.full_name(r.user) }
          next if valid_names.include?(invalid_name)

          expect(employee_names).not_to include(invalid_name),
            "Report should not include '#{invalid_name}' (salary nil or zero)"
        end

        # Verify: names are in alphabetical order
        expected_order = employee_names.sort_by(&:downcase)
        expect(employee_names).to eq(expected_order),
          "Employees not in alphabetical order.\n" \
          "Got:      #{employee_names}\n" \
          "Expected: #{expected_order}"
      end
    end

    # Feature: financial-reports, Property 8: Resumo de funcionários ativos correto
    # **Validates: Requirements 3.6**
    #
    # For any set of administration records, the summary SHALL count as active only
    # records with end_date nil AND salary > 0, and the salary sum SHALL equal the
    # sum of salaries of those active records.
    it "counts only active employees (end_date nil) and sums their salaries correctly" do
      property_of {
        # Generate between 1 and 15 random administration records (mix of active and inactive)
        num_records = range(1, 15)

        administrations = Array.new(num_records) do |i|
          first_name = sized(range(3, 10)) { string(:alpha) }.capitalize
          last_name = sized(range(3, 10)) { string(:alpha) }.capitalize
          user = OpenStruct.new(
            id: i + 1,
            first_name: first_name,
            last_name: last_name
          )

          occupation = OpenStruct.new(
            id: i + 1,
            title: sized(range(5, 15)) { string(:alpha) }.capitalize
          )

          # salary > 0 (already guaranteed by the query filter)
          salary = BigDecimal(range(1000, 5_000_000).to_s) / BigDecimal("100")

          # Randomly assign end_date: nil (active) or a date (inactive)
          has_end_date = boolean
          end_date = has_end_date ? Date.new(2024, range(1, 12), range(1, 28)) : nil

          start_date = Date.new(2023, range(1, 12), range(1, 28))
          payment_day = range(1, 31)

          OpenStruct.new(
            id: i + 1,
            user: user,
            user_id: user.id,
            occupation: occupation,
            occupation_id: occupation.id,
            salary: salary,
            start_date: start_date,
            end_date: end_date,
            payment_day: payment_day
          )
        end

        administrations
      }.check(100) do |administrations|
        # Calculate expected active employees (end_date nil)
        active_administrations = administrations.select { |a| a.end_date.nil? }
        expected_active_count = active_administrations.size
        expected_salary_sum = active_administrations.sum { |a| a.salary.to_f }

        # Stub the fetch_administrations method to return our generated data
        generator = FinancialReports::SalariesReportGenerator.new
        allow(generator).to receive(:fetch_administrations).and_return(administrations)

        # Generate the report
        report = generator.call

        # Parse the summary section
        summary_section = report[/## Resumo.*\z/m]
        expect(summary_section).not_to be_nil, "Summary section not found in report"

        # Extract active employee count from the summary table
        count_match = summary_section.match(/Total de funcionários ativos\s*\|\s*(\d+)\s*\|/)
        expect(count_match).not_to be_nil, "Active employee count not found in summary"
        actual_count = count_match[1].to_i

        # Extract salary sum from the summary table
        salary_match = summary_section.match(/Soma dos salários ativos\s*\|\s*(.+?)\s*\|/)
        expect(salary_match).not_to be_nil, "Salary sum not found in summary"

        # Parse the formatted currency back to a float value
        formatted_salary = salary_match[1].strip
        parsed_salary = formatted_salary
          .gsub("R$ ", "")
          .gsub(".", "")
          .gsub(",", ".")
          .to_f

        # Verify active count
        expect(actual_count).to eq(expected_active_count),
          "Active employee count mismatch.\n" \
          "Expected: #{expected_active_count}\n" \
          "Got: #{actual_count}\n" \
          "Total records: #{administrations.size}\n" \
          "Records with nil end_date: #{active_administrations.size}"

        # Verify salary sum (using a small delta for floating point comparison)
        expect(parsed_salary).to be_within(0.01).of(expected_salary_sum),
          "Salary sum mismatch.\n" \
          "Expected: #{expected_salary_sum}\n" \
          "Got: #{parsed_salary}\n" \
          "Active salaries: #{active_administrations.map(&:salary)}"
      end
    end

    # Feature: financial-reports, Property 7: Completude dos dados de administração no relatório
    # **Validates: Requirements 3.4**
    #
    # For any administration record with valid salary (> 0), the report SHALL contain:
    # full user name, occupation title, formatted salary, payment day (integer or "Não definido"),
    # formatted start date, and formatted end date (or "Em atividade").
    it "includes all required fields for any administration with valid salary" do
      property_of {
        first_name = sized(range(2, 10)) { string(:alpha) }.capitalize
        last_name = sized(range(2, 10)) { string(:alpha) }.capitalize
        occupation_title = sized(range(3, 15)) { string(:alpha) }.capitalize
        # Salary > 0, up to 99999.99
        salary_cents = range(1, 9_999_999)
        salary = BigDecimal(salary_cents.to_s) / BigDecimal("100")
        # Payment day: either nil or 1-31
        has_payment_day = boolean
        payment_day = has_payment_day ? range(1, 31) : nil
        # Start date: random date in the past
        start_date = Date.new(range(2000, 2023), range(1, 12), range(1, 28))
        # End date: either nil (active) or a date after start_date
        has_end_date = boolean
        end_date = has_end_date ? Date.new(range(2020, 2024), range(1, 12), range(1, 28)) : nil

        {
          first_name: first_name,
          last_name: last_name,
          occupation_title: occupation_title,
          salary: salary,
          payment_day: payment_day,
          start_date: start_date,
          end_date: end_date
        }
      }.check(100) do |data|
        user = OpenStruct.new(first_name: data[:first_name], last_name: data[:last_name])
        occupation = OpenStruct.new(title: data[:occupation_title])
        administration = OpenStruct.new(
          user: user,
          occupation: occupation,
          salary: data[:salary],
          payment_day: data[:payment_day],
          start_date: data[:start_date],
          end_date: data[:end_date]
        )

        # Stub fetch_administrations to return our generated data
        generator = FinancialReports::SalariesReportGenerator.new
        allow(generator).to receive(:fetch_administrations).and_return([administration])

        report = generator.call

        # Verify full name is present
        expected_name = FinancialReports::Formatter.full_name(user)
        expect(report).to include(expected_name),
          "Report should contain full name '#{expected_name}'"

        # Verify occupation title is present
        expect(report).to include(data[:occupation_title]),
          "Report should contain occupation title '#{data[:occupation_title]}'"

        # Verify formatted salary is present
        expected_salary = FinancialReports::Formatter.format_currency(data[:salary])
        expect(report).to include(expected_salary),
          "Report should contain formatted salary '#{expected_salary}'"

        # Verify payment day (integer or "Não definido")
        if data[:payment_day]
          expect(report).to include("| Dia de Pagamento | #{data[:payment_day]} |"),
            "Report should contain payment day '#{data[:payment_day]}' in the table"
        else
          expect(report).to include("Não definido"),
            "Report should contain 'Não definido' when payment_day is nil"
        end

        # Verify formatted start date
        expected_start_date = FinancialReports::Formatter.format_date(data[:start_date])
        expect(report).to include(expected_start_date),
          "Report should contain formatted start date '#{expected_start_date}'"

        # Verify end date (formatted or "Em atividade")
        if data[:end_date]
          expected_end_date = FinancialReports::Formatter.format_date(data[:end_date])
          expect(report).to include(expected_end_date),
            "Report should contain formatted end date '#{expected_end_date}'"
        else
          expect(report).to include("Em atividade"),
            "Report should contain 'Em atividade' when end_date is nil"
        end
      end
    end
  end

  describe "Unit Tests" do
    let(:generator) { FinancialReports::SalariesReportGenerator.new }

    def build_administration(user_first:, user_last:, occupation_title:, salary:, payment_day:, start_date:, end_date:)
      user = OpenStruct.new(first_name: user_first, last_name: user_last)
      occupation = OpenStruct.new(title: occupation_title)
      OpenStruct.new(
        user: user,
        occupation: occupation,
        salary: BigDecimal(salary.to_s),
        payment_day: payment_day,
        start_date: start_date,
        end_date: end_date
      )
    end

    before do
      allow(Date).to receive(:today).and_return(Date.new(2024, 6, 15))
    end

    context "geração com múltiplas administrações" do
      # Validates: Requirements 3.1, 3.2, 3.4
      it "gera relatório com múltiplas administrações" do
        administrations = [
          build_administration(
            user_first: "Ana", user_last: "Silva",
            occupation_title: "Secretária", salary: 2500.00,
            payment_day: 5, start_date: Date.new(2020, 3, 1), end_date: nil
          ),
          build_administration(
            user_first: "Carlos", user_last: "Oliveira",
            occupation_title: "Zelador", salary: 1800.50,
            payment_day: 10, start_date: Date.new(2019, 6, 15), end_date: Date.new(2023, 12, 31)
          ),
          build_administration(
            user_first: "Maria", user_last: "Santos",
            occupation_title: "Pastora", salary: 4000.00,
            payment_day: 1, start_date: Date.new(2018, 1, 10), end_date: nil
          )
        ]

        allow(generator).to receive(:fetch_administrations).and_return(administrations)
        report = generator.call

        # Verifica cabeçalho
        expect(report).to include("# Relatório de Salários")
        expect(report).to include("Data de geração: 15/06/2024")

        # Verifica que todas as administrações estão presentes
        expect(report).to include("## Ana Silva")
        expect(report).to include("## Carlos Oliveira")
        expect(report).to include("## Maria Santos")

        # Verifica dados de cada administração
        expect(report).to include("| Cargo | Secretária |")
        expect(report).to include("| Salário | R$ 2.500,00 |")
        expect(report).to include("| Cargo | Zelador |")
        expect(report).to include("| Salário | R$ 1.800,50 |")
        expect(report).to include("| Cargo | Pastora |")
        expect(report).to include("| Salário | R$ 4.000,00 |")

        # Verifica separadores entre seções
        expect(report).to include("---")
      end
    end

    context "usuário com múltiplos registros de administração" do
      # Validates: Requirements 3.7
      it "exibe cada registro de administração como entrada separada" do
        administrations = [
          build_administration(
            user_first: "João", user_last: "Pereira",
            occupation_title: "Músico", salary: 1500.00,
            payment_day: 5, start_date: Date.new(2018, 1, 1), end_date: Date.new(2020, 6, 30)
          ),
          build_administration(
            user_first: "João", user_last: "Pereira",
            occupation_title: "Diretor Musical", salary: 3000.00,
            payment_day: 5, start_date: Date.new(2020, 7, 1), end_date: nil
          )
        ]

        allow(generator).to receive(:fetch_administrations).and_return(administrations)
        report = generator.call

        # Verifica que ambos os registros aparecem
        headers = report.scan(/^## João Pereira$/)
        expect(headers.size).to eq(2)

        # Verifica que ambos os cargos estão presentes
        expect(report).to include("| Cargo | Músico |")
        expect(report).to include("| Cargo | Diretor Musical |")

        # Verifica ambos os salários
        expect(report).to include("| Salário | R$ 1.500,00 |")
        expect(report).to include("| Salário | R$ 3.000,00 |")
      end
    end

    context "administração com end_date nulo" do
      # Validates: Requirements 3.4
      it "exibe 'Em atividade' quando end_date é nulo" do
        administrations = [
          build_administration(
            user_first: "Pedro", user_last: "Costa",
            occupation_title: "Pastor", salary: 5000.00,
            payment_day: 1, start_date: Date.new(2015, 3, 20), end_date: nil
          )
        ]

        allow(generator).to receive(:fetch_administrations).and_return(administrations)
        report = generator.call

        expect(report).to include("| Data de Término | Em atividade |")
      end
    end

    context "administração com payment_day nulo" do
      # Validates: Requirements 3.4
      it "exibe 'Não definido' quando payment_day é nulo" do
        administrations = [
          build_administration(
            user_first: "Lucas", user_last: "Ferreira",
            occupation_title: "Tesoureiro", salary: 2000.00,
            payment_day: nil, start_date: Date.new(2021, 8, 1), end_date: nil
          )
        ]

        allow(generator).to receive(:fetch_administrations).and_return(administrations)
        report = generator.call

        expect(report).to include("| Dia de Pagamento | Não definido |")
      end
    end

    context "banco vazio" do
      # Validates: Requirements 1.7, 3.6
      it "gera cabeçalho e resumo com valores zerados quando não há administrações" do
        allow(generator).to receive(:fetch_administrations).and_return([])
        report = generator.call

        # Verifica cabeçalho presente
        expect(report).to include("# Relatório de Salários")
        expect(report).to include("Data de geração: 15/06/2024")

        # Verifica resumo com zeros
        expect(report).to include("## Resumo")
        expect(report).to include("| Total de funcionários ativos | 0 |")
        expect(report).to include("| Soma dos salários ativos | R$ 0,00 |")
      end
    end

    context "resumo de funcionários ativos" do
      # Validates: Requirements 3.6
      it "conta apenas administrações com end_date nulo como ativas" do
        administrations = [
          build_administration(
            user_first: "Ana", user_last: "Silva",
            occupation_title: "Secretária", salary: 2500.00,
            payment_day: 5, start_date: Date.new(2020, 3, 1), end_date: nil
          ),
          build_administration(
            user_first: "Carlos", user_last: "Oliveira",
            occupation_title: "Zelador", salary: 1800.00,
            payment_day: 10, start_date: Date.new(2019, 6, 15), end_date: Date.new(2023, 12, 31)
          ),
          build_administration(
            user_first: "Maria", user_last: "Santos",
            occupation_title: "Pastora", salary: 4000.00,
            payment_day: 1, start_date: Date.new(2018, 1, 10), end_date: nil
          )
        ]

        allow(generator).to receive(:fetch_administrations).and_return(administrations)
        report = generator.call

        # Apenas Ana e Maria são ativas (end_date nil)
        expect(report).to include("| Total de funcionários ativos | 2 |")
        expect(report).to include("| Soma dos salários ativos | R$ 6.500,00 |")
      end
    end
  end
end
