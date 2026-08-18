# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ConsistencyChecks::Orchestrator, feature_category: :vulnerability_management do
  let_it_be(:project) { build_stubbed(:project) }

  describe 'CONSISTENCY_CHECKS' do
    subject(:consistency_checks) { described_class::CONSISTENCY_CHECKS }

    it 'includes TriggerParityCheck' do
      expect(consistency_checks).to include(Vulnerabilities::ConsistencyChecks::TriggerParityCheck)
    end

    it 'includes all expected checks' do
      expect(consistency_checks).to match_array([
        Vulnerabilities::ConsistencyChecks::HasVulnerabilitiesIsCorrectCheck,
        Vulnerabilities::ConsistencyChecks::BackfillIssueLinkOccurrenceIdCheck,
        Vulnerabilities::ConsistencyChecks::BackfillMergeRequestLinkOccurrenceIdCheck,
        Vulnerabilities::ConsistencyChecks::TriggerParityCheck
      ])
    end
  end

  describe '#execute' do
    subject(:execute) { described_class.new(project).execute }

    it 'executes each consistency check on the project' do
      expect(described_class::CONSISTENCY_CHECKS).to all(receive(:enqueue).with(project))

      execute
    end
  end
end
