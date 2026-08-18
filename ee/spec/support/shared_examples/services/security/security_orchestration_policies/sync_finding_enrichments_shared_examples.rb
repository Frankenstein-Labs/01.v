# frozen_string_literal: true

RSpec.shared_examples 'syncs finding enrichments for approval policy with enrichment filters' do
  context 'when policy has enrichment filters' do
    before do
      rule = security_policy.approval_policy_rules.first
      raise "Expected security policy to have at least one approval policy rule" unless rule

      rule.update!(
        content: rule.content.merge(
          'vulnerability_attributes' => { 'epss_score' => { 'operator' => 'greater_than', 'value' => 0.5 } }
        )
      )
    end

    it 'enqueues SyncProjectFindingEnrichmentsWorker' do
      expect(Security::ScanResultPolicies::SyncProjectFindingEnrichmentsWorker)
        .to receive(:perform_async).with(project.id, security_policy.id)

      service.execute
    end
  end

  context 'when policy does not have enrichment filters' do
    it 'does not enqueue SyncProjectFindingEnrichmentsWorker' do
      expect(Security::ScanResultPolicies::SyncProjectFindingEnrichmentsWorker)
        .not_to receive(:perform_async)

      service.execute
    end
  end
end
