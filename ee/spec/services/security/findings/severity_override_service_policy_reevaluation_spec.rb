# frozen_string_literal: true

require 'spec_helper'

# Isolated coverage for the pre-existing-state policy re-evaluation wired into
# Security::Findings::SeverityOverrideService. The vulnerability resolution is stubbed so
# this spec owns its records and does not collide with severity_override_service_spec's
# shared dependency-scanning fixtures.
RSpec.describe Security::Findings::SeverityOverrideService, feature_category: :security_policy_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:security_finding) { create(:security_finding) }
  let_it_be(:project) { security_finding.project }
  let_it_be(:vulnerability) { create(:vulnerability, severity: :low, project: project) }

  let(:worker) { Security::ScanResultPolicies::SyncProjectPreexistingStatesApprovalRulesWorker }
  let(:triaged_project) { project }
  let(:new_severity) { 'high' }

  subject(:execute) do
    described_class.new(user: user, security_finding: security_finding, severity: new_severity).execute
  end

  before_all do
    project.add_maintainer(user)
  end

  before do
    stub_licensed_features(security_dashboard: true)
    stub_feature_flags(hide_vulnerability_severity_override: false)
    allow_next_instance_of(Vulnerabilities::FindOrCreateFromSecurityFindingService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { vulnerability: vulnerability }))
    end
    # Isolate the wiring under test from the real severity persistence (covered by
    # severity_override_service_spec) and its vulnerability-read DB-trigger machinery.
    allow_next_instance_of(described_class) do |service|
      allow(service).to receive(:update_severity)
      allow(service).to receive(:audit)
    end
  end

  context 'when the severity changes' do
    it_behaves_like 'syncs pre-existing state approval policy rules on triage' do
      let(:perform_triage) { execute }
    end
  end

  context 'when the severity is unchanged' do
    let(:new_severity) { vulnerability.severity }

    it 'does not schedule the re-evaluation' do
      expect(worker).not_to receive(:perform_in)

      execute
    end
  end
end
