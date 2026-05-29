# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "pathname"
require "ostruct"
require "date"
require "active_support/core_ext/object/blank"
require_relative "../../../lib/financial_reports/formatter"
require_relative "../../../lib/financial_reports/tithes_report_generator"
require_relative "../../../lib/financial_reports/salaries_report_generator"
require_relative "../../../lib/financial_reports/monthly_financial_summary_generator"

# Stub Rails before requiring runner (which uses Rails.root at load time)
unless defined?(Rails)
  module Rails
    def self.root
      Pathname.new(File.expand_path("../../..", __dir__))
    end
  end
end

require_relative "../../../lib/financial_reports/runner"

RSpec.describe FinancialReports::Runner do
  let(:runner) { FinancialReports::Runner.new }
  let(:output_dir) { FinancialReports::Runner::OUTPUT_DIR }

  before do
    # Stub ActiveRecord and models for unit testing
    stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
    allow(ActiveRecord::Base).to receive(:connection).and_return(double("connection", active?: true))

    # Stub Movement and Administration models
    stub_const("Movement", double("Movement"))
    stub_const("Administration", double("Administration"))

    # Default: database has data
    tithe_relation = double("tithe_relation")
    allow(Movement).to receive(:where).with(sub_kind_of: :dízimo).and_return(tithe_relation)
    allow(tithe_relation).to receive(:exists?).and_return(true)

    admin_where = double("admin_where")
    admin_not_relation = double("admin_not_relation")
    admin_filtered = double("admin_filtered")
    allow(Administration).to receive(:where).with(no_args).and_return(admin_where)
    allow(admin_where).to receive(:not).with(salary: nil).and_return(admin_not_relation)
    allow(admin_not_relation).to receive(:where).with("salary > 0").and_return(admin_filtered)
    allow(admin_filtered).to receive(:exists?).and_return(true)

    # Stub report generators
    allow(FinancialReports::TithesReportGenerator).to receive(:call).and_return("# Relatório de Dízimos\n")
    allow(FinancialReports::SalariesReportGenerator).to receive(:call).and_return("# Relatório de Salários\n")
    allow(FinancialReports::MonthlyFinancialSummaryGenerator).to receive(:call).and_return("# Resumo Financeiro Mensal\n")

    # Use a temp directory for output
    @temp_dir = Dir.mktmpdir("financial_reports_test")
    stub_const("FinancialReports::Runner::OUTPUT_DIR", Pathname.new(@temp_dir))
  end

  after do
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  describe "#call" do
    context "criação do diretório de saída" do
      # Validates: Requirement 1.2
      it "cria o diretório de saída se não existir" do
        new_dir = File.join(@temp_dir, "subdir")
        stub_const("FinancialReports::Runner::OUTPUT_DIR", Pathname.new(new_dir))

        expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout
        expect(Dir.exist?(new_dir)).to be true
      end
    end

    context "sobrescrita de arquivos existentes" do
      # Validates: Requirement 1.3
      it "sobrescreve arquivos existentes com o mesmo nome" do
        # Create existing files with old content
        File.write(File.join(@temp_dir, "dizimos_por_membro.md"), "conteúdo antigo")
        File.write(File.join(@temp_dir, "salarios.md"), "conteúdo antigo")

        expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout

        # Verify files were overwritten
        expect(File.read(File.join(@temp_dir, "dizimos_por_membro.md"))).to eq("# Relatório de Dízimos\n")
        expect(File.read(File.join(@temp_dir, "salarios.md"))).to eq("# Relatório de Salários\n")
      end
    end

    context "exibição do resumo final" do
      # Validates: Requirement 1.4
      it "exibe o caminho absoluto e lista de arquivos gerados" do
        expected_output = /Relatórios gerados em: .+\n\s+- dizimos_por_membro\.md\n\s+- salarios\.md\n\s+- resumo_financeiro_mensal\.md/

        expect { runner.call }.to output(expected_output).to_stdout
      end
    end

    context "gravação com codificação UTF-8 e LF" do
      # Validates: Requirement 4.4
      it "grava arquivos com codificação UTF-8" do
        allow(FinancialReports::TithesReportGenerator).to receive(:call).and_return("Dízimos com acentuação: ção, ã, é\n")

        expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout

        content = File.read(File.join(@temp_dir, "dizimos_por_membro.md"), encoding: "UTF-8")
        expect(content.encoding.to_s).to eq("UTF-8")
        expect(content).to include("Dízimos com acentuação: ção, ã, é")
      end

      it "normaliza quebras de linha CRLF para LF" do
        allow(FinancialReports::TithesReportGenerator).to receive(:call).and_return("Linha 1\r\nLinha 2\r\n")

        expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout

        content = File.binread(File.join(@temp_dir, "dizimos_por_membro.md"))
        expect(content).not_to include("\r\n")
        expect(content).to include("Linha 1\nLinha 2\n")
      end
    end
  end

  describe "tratamento de erro de conexão com banco" do
    # Validates: Requirement 1.5
    it "exibe mensagem de erro e encerra com exit(1) quando conexão falha com exceção" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError.new("Connection refused"))

      expect {
        begin
          runner.call
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end
      }.to output(/Erro: Não foi possível conectar ao banco de dados\./).to_stdout
    end

    it "exibe mensagem de erro e encerra com exit(1) quando connection.active? retorna false" do
      allow(ActiveRecord::Base).to receive(:connection).and_return(double("connection", active?: false))

      expect {
        begin
          runner.call
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end
      }.to output(/Erro: Não foi possível conectar ao banco de dados\./).to_stdout
    end
  end

  describe "tratamento de erro de permissão de escrita" do
    # Validates: Requirement 1.6
    it "exibe mensagem de erro e encerra com exit(1) quando não tem permissão de escrita" do
      allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES.new("Permission denied"))

      expect {
        begin
          runner.call
        rescue SystemExit => e
          expect(e.status).to eq(1)
        end
      }.to output(/Erro: Sem permissão de escrita no diretório de saída\./).to_stdout
    end
  end

  describe "aviso com banco vazio" do
    # Validates: Requirement 1.7
    it "exibe aviso quando não há dados financeiros no banco" do
      tithe_relation = double("tithe_relation")
      allow(Movement).to receive(:where).with(sub_kind_of: :dízimo).and_return(tithe_relation)
      allow(tithe_relation).to receive(:exists?).and_return(false)

      admin_where = double("admin_where")
      admin_not_relation = double("admin_not_relation")
      admin_filtered = double("admin_filtered")
      allow(Administration).to receive(:where).with(no_args).and_return(admin_where)
      allow(admin_where).to receive(:not).with(salary: nil).and_return(admin_not_relation)
      allow(admin_not_relation).to receive(:where).with("salary > 0").and_return(admin_filtered)
      allow(admin_filtered).to receive(:exists?).and_return(false)

      expected_output = /Aviso: Nenhum dado financeiro encontrado no banco de dados\./

      expect { runner.call }.to output(expected_output).to_stdout
    end

    it "não exibe aviso quando há dízimos no banco" do
      tithe_relation = double("tithe_relation")
      allow(Movement).to receive(:where).with(sub_kind_of: :dízimo).and_return(tithe_relation)
      allow(tithe_relation).to receive(:exists?).and_return(true)

      admin_where = double("admin_where")
      admin_not_relation = double("admin_not_relation")
      admin_filtered = double("admin_filtered")
      allow(Administration).to receive(:where).with(no_args).and_return(admin_where)
      allow(admin_where).to receive(:not).with(salary: nil).and_return(admin_not_relation)
      allow(admin_not_relation).to receive(:where).with("salary > 0").and_return(admin_filtered)
      allow(admin_filtered).to receive(:exists?).and_return(false)

      expect { runner.call }.not_to output(/Aviso:/).to_stdout
    end

    it "não exibe aviso quando há salários no banco" do
      tithe_relation = double("tithe_relation")
      allow(Movement).to receive(:where).with(sub_kind_of: :dízimo).and_return(tithe_relation)
      allow(tithe_relation).to receive(:exists?).and_return(false)

      admin_where = double("admin_where")
      admin_not_relation = double("admin_not_relation")
      admin_filtered = double("admin_filtered")
      allow(Administration).to receive(:where).with(no_args).and_return(admin_where)
      allow(admin_where).to receive(:not).with(salary: nil).and_return(admin_not_relation)
      allow(admin_not_relation).to receive(:where).with("salary > 0").and_return(admin_filtered)
      allow(admin_filtered).to receive(:exists?).and_return(true)

      expect { runner.call }.not_to output(/Aviso:/).to_stdout
    end
  end

  describe "orquestração dos geradores" do
    it "invoca TithesReportGenerator, SalariesReportGenerator e MonthlyFinancialSummaryGenerator" do
      expect(FinancialReports::TithesReportGenerator).to receive(:call).and_return("tithes content")
      expect(FinancialReports::SalariesReportGenerator).to receive(:call).and_return("salaries content")
      expect(FinancialReports::MonthlyFinancialSummaryGenerator).to receive(:call).and_return("monthly summary content")

      expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout
    end

    it "gera os três arquivos no diretório de saída" do
      expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout

      expect(File.exist?(File.join(@temp_dir, "dizimos_por_membro.md"))).to be true
      expect(File.exist?(File.join(@temp_dir, "salarios.md"))).to be true
      expect(File.exist?(File.join(@temp_dir, "resumo_financeiro_mensal.md"))).to be true
    end
  end

  describe "integração com MonthlyFinancialSummaryGenerator" do
    # Validates: Requirements 1.2, 8.4

    context "quando MonthlyFinancialSummaryGenerator.call sucede" do
      it "inclui resumo_financeiro_mensal.md na lista de arquivos gerados exibida no terminal" do
        allow(FinancialReports::MonthlyFinancialSummaryGenerator).to receive(:call).and_return("# Resumo Financeiro Mensal\n")

        expect { runner.call }.to output(/- resumo_financeiro_mensal\.md/).to_stdout
      end
    end

    context "quando MonthlyFinancialSummaryGenerator.call lança StandardError" do
      before do
        allow(FinancialReports::MonthlyFinancialSummaryGenerator).to receive(:call).and_raise(StandardError.new("falha na consulta"))
      end

      it "não interrompe a geração dos demais relatórios (dizimos e salarios)" do
        expect { runner.call }.to output(/Relatórios gerados em:/).to_stdout

        expect(File.exist?(File.join(@temp_dir, "dizimos_por_membro.md"))).to be true
        expect(File.exist?(File.join(@temp_dir, "salarios.md"))).to be true
      end

      it "exibe mensagem de erro no terminal com a mensagem da exceção" do
        expect { runner.call }.to output(/Erro ao gerar relatório mensal: falha na consulta/).to_stdout
      end
    end
  end
end
