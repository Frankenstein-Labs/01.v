# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'vulnerabilities rake tasks', feature_category: :vulnerability_management do
  include RakeHelpers

  before_all do
    Rake.application.rake_require 'ee/lib/tasks/gitlab/vulnerabilities/fix_auto_resolved_vulnerabilities',
      [Rails.root.to_s]
    Rake::Task.define_task(:environment)
  end

  describe 'fix_auto_resolved_vulnerabilities' do
    let(:args) { ['123456'] }

    subject(:task) { run_rake_task('gitlab:vulnerabilities:fix_auto_resolved_vulnerabilities', args) }

    it 'calls rake service with args' do
      expect_next_instance_of(Vulnerabilities::Rake::FixAutoResolvedVulnerabilities, args) do |instance|
        expect(instance).to receive(:execute)
      end

      task
    end
  end

  describe 'fix_auto_resolved_vulnerabilities:revert' do
    let(:args) { ['123456'] }

    subject(:task) { run_rake_task('gitlab:vulnerabilities:fix_auto_resolved_vulnerabilities:revert', args) }

    it 'calls rake service with args' do
      expect_next_instance_of(Vulnerabilities::Rake::FixAutoResolvedVulnerabilities, args, revert: true) do |instance|
        expect(instance).to receive(:execute)
      end

      task
    end
  end
end
