namespace :financial_reports do
  desc "Gera relatórios financeiros em Markdown (dízimos por membro e salários)"
  task generate: :environment do
    FinancialReports::Runner.call
  end
end
