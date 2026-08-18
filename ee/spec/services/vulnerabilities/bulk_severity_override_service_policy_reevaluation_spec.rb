# frozen_string_literal: true

require 'spec_helper'

# Non-elastic coverage for the pre-existing-state policy re-evaluation wired into
# BulkSeverityOverrideService#update_vulnerabilities!'s after_commit block. The main
# bulk_severity_override_service_spec is :elastic-tagged and only runs in CI.
RSpec.describe Vulnerabilities::BulkSeverityOverrideService, feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, severity: :high, project: project) }

  let(:triaged_project) { project }

  subject(:service) { described_class.new(user, [vulnerability.id], 'comment', 'critical') }

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
    stub_feature_flags(hide_vulnerability_severity_override: false)
    allow_next_instance_of(Vulnerabilities::BulkEsOperationService) do |es_service|
      allow(es_service).to receive(:execute)
    end
  end

  it_behaves_like 'syncs pre-existing state approval policy rules on triage' do
    let(:perform_triage) { service.execute }
  end
end
