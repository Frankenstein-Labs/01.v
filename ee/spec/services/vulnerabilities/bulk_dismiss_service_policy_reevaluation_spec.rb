# frozen_string_literal: true

require 'spec_helper'

# Non-elastic coverage for the pre-existing-state policy re-evaluation wired into
# BulkDismissService#update's after_commit block (see SyncOnVulnerabilityStateChange).
# The main bulk_dismiss_service_spec is :elastic-tagged and only runs in CI; this
# verifies the after_commit scheduling without an Elasticsearch service.
RSpec.describe Vulnerabilities::BulkDismissService, feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :detected, project: project) }

  let(:triaged_project) { project }

  subject(:service) { described_class.new(user, [vulnerability.id], 'comment', 'used_in_tests') }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
    # Avoid requiring a live Elasticsearch service for this DB-only assertion.
    allow_next_instance_of(Vulnerabilities::BulkEsOperationService) do |es_service|
      allow(es_service).to receive(:execute)
    end
  end

  it_behaves_like 'syncs pre-existing state approval policy rules on triage' do
    let(:perform_triage) { service.execute }
  end
end
