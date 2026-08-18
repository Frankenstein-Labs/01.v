# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks, feature_category: :vulnerability_management do
  let_it_be(:project) { build_stubbed(:project) }

  describe '.ensure_consistency_on_project!' do
    subject(:ensure_consistency_on_project!) { described_class.ensure_consistency_on_project!(project) }

    it 'executes orchestrator on project' do
      expect_next_instance_of(::Vulnerabilities::ConsistencyChecks::Orchestrator, project) do |instance|
        expect(instance).to receive(:execute)
      end

      ensure_consistency_on_project!
    end

    context 'when vulnerability_consistency_checks is disabled' do
      before do
        stub_feature_flags(vulnerability_consistency_checks: false)
      end

      it 'does not execute orchestrator' do
        expect(::Vulnerabilities::ConsistencyChecks::Orchestrator).not_to receive(:new)

        ensure_consistency_on_project!
      end
    end
  end
end
