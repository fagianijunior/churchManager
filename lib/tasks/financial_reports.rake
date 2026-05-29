require_relative "../financial_reports/formatter"
require_relative "../financial_reports/tithes_report_generator"
require_relative "../financial_reports/salaries_report_generator"
require_relative "../financial_reports/monthly_financial_summary_generator"
require_relative "../financial_reports/runner"

namespace :financial_reports do
  desc "Gera relatórios financeiros em Markdown (dízimos por membro e salários)"
  task generate: :environment do
    FinancialReports::Runner.call
  end
end
