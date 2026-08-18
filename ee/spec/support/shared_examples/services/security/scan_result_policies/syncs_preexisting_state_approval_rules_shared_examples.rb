# frozen_string_literal: true

# Shared behaviour for vulnerability triage services that must re-evaluate
# pre-existing vulnerability state approval policy rules for open merge requests.
#
# Host context must define:
#   - `triaged_project` : the Project expected to be re-evaluated
#   - `perform_triage`   : a callable expression that performs the triage (e.g. `service.execute`)
RSpec.shared_examples 'syncs pre-existing state approval policy rules on triage' do
  it 'schedules a project-wide pre-existing state policy re-evaluation' do
    expect(Security::ScanResultPolicies::SyncProjectPreexistingStatesApprovalRulesWorker).to receive(:perform_in).with(
      Security::ScanResultPolicies::SyncOnVulnerabilityStateChange::SYNC_POLICIES_DELAY,
      triaged_project.id
    )

    perform_triage
  end

  context 'when the reevaluate_preexisting_states_on_vulnerability_triage flag is disabled' do
    before do
      stub_feature_flags(reevaluate_preexisting_states_on_vulnerability_triage: false)
    end

    it 'does not schedule the re-evaluation' do
      expect(Security::ScanResultPolicies::SyncProjectPreexistingStatesApprovalRulesWorker)
        .not_to receive(:perform_in)

      perform_triage
    end
  end
end
