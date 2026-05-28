# frozen_string_literal: true

require "spec_helper"
require "rake"
require "pathname"

# Stub Rails before requiring the rake task and runner
unless defined?(Rails)
  module Rails
    def self.root
      Pathname.new(File.expand_path("../..", __dir__))
    end
  end
end

require_relative "../../lib/financial_reports/formatter"
require_relative "../../lib/financial_reports/tithes_report_generator"
require_relative "../../lib/financial_reports/salaries_report_generator"
require_relative "../../lib/financial_reports/runner"

RSpec.describe "financial_reports:generate rake task" do
  let(:rake_file) { File.join(Rails.root, "lib", "tasks", "financial_reports.rake") }

  before(:each) do
    Rake.application = Rake::Application.new
    Rake.application.options.trace = false
    Rake::TaskManager.record_task_metadata = true
    Rake::Task.define_task(:environment)
    load rake_file
  end

  after(:each) do
    Rake.application.clear
  end

  # Validates: Requirement 1.1
  describe "task existence and invocability" do
    it "is defined under the financial_reports namespace with name generate" do
      expect(Rake::Task.task_defined?("financial_reports:generate")).to be true
    end

    it "depends on the :environment task" do
      task = Rake::Task["financial_reports:generate"]
      expect(task.prerequisites).to include("environment")
    end

    it "has a description" do
      task = Rake::Task["financial_reports:generate"]
      expect(task.comment).to include("relatórios financeiros")
    end
  end

  # Validates: Requirement 1.1
  describe "task execution" do
    it "invokes FinancialReports::Runner.call" do
      expect(FinancialReports::Runner).to receive(:call)

      Rake::Task["financial_reports:generate"].invoke
    end

    it "can be invoked multiple times after reenabling" do
      expect(FinancialReports::Runner).to receive(:call).twice

      task = Rake::Task["financial_reports:generate"]
      task.invoke
      task.reenable
      task.invoke
    end
  end
end
