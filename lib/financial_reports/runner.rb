# frozen_string_literal: true

require "fileutils"

module FinancialReports
  class Runner
    OUTPUT_DIR = Rails.root.join("tmp", "financial_reports")

    def self.call
      new.call
    end

    def call
      validate_prerequisites!
      ensure_output_directory!
      check_empty_database
      generate_reports
      print_summary
    end

    private

    def validate_prerequisites!
      validate_database_connection!
      validate_write_permission!
    end

    def validate_database_connection!
      ActiveRecord::Base.connection.active?
    rescue StandardError
      puts "Erro: Não foi possível conectar ao banco de dados."
      exit(1)
    else
      unless ActiveRecord::Base.connection.active?
        puts "Erro: Não foi possível conectar ao banco de dados."
        exit(1)
      end
    end

    def validate_write_permission!
      FileUtils.mkdir_p(OUTPUT_DIR)
      test_file = OUTPUT_DIR.join(".write_test")
      File.write(test_file, "")
      File.delete(test_file)
    rescue Errno::EACCES
      puts "Erro: Sem permissão de escrita no diretório de saída."
      exit(1)
    end

    def ensure_output_directory!
      FileUtils.mkdir_p(OUTPUT_DIR)
    end

    def check_empty_database
      has_tithes = Movement.where(sub_kind_of: :dízimo).exists?
      has_salaries = Administration.where.not(salary: nil).where("salary > 0").exists?

      unless has_tithes || has_salaries
        puts "Aviso: Nenhum dado financeiro encontrado no banco de dados."
      end
    end

    def generate_reports
      @generated_files = []
      @generated_files << write_report("dizimos_por_membro.md", TithesReportGenerator.call)
      @generated_files << write_report("salarios.md", SalariesReportGenerator.call)

      begin
        @generated_files << write_report("resumo_financeiro_mensal.md", MonthlyFinancialSummaryGenerator.call)
      rescue StandardError => e
        puts "Erro ao gerar relatório mensal: #{e.message}"
      end
    end

    def write_report(filename, content)
      path = OUTPUT_DIR.join(filename)
      # Ensure LF line endings (replace any CRLF with LF)
      normalized_content = content.gsub("\r\n", "\n")
      File.write(path, normalized_content, encoding: "UTF-8")
      filename
    end

    def print_summary
      puts "Relatórios gerados em: #{OUTPUT_DIR.realpath}"
      @generated_files.each { |f| puts "  - #{f}" }
    end
  end
end
