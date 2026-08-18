# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::DirectReassignService, feature_category: :importers do
  let_it_be(:import_source_user) do
    create(:import_source_user, :reassignment_in_progress)
  end

  let_it_be(:reassign_to_user_id) { import_source_user.reassign_to_user.id }
  let_it_be(:placeholder_user_id) { import_source_user.placeholder_user.id }

  let(:reassignment_throttling) { Import::ReassignPlaceholderThrottling.new(import_source_user) }

  subject(:direct_reassign) do
    described_class.new(import_source_user, reassignment_throttling: reassignment_throttling, sleep_time: 0)
  end

  describe '#execute' do
    context 'when reassigning Vulnerability model' do
      let_it_be_with_reload(:vulnerability) do
        create(:vulnerability, author_id: placeholder_user_id)
      end

      context 'and the single reassignment fallback is necessary' do
        # Triggering this context would require complex error mocking for a temporary test.
        # It's easier to just test the fallback behaviour directly with send
        it 'uses feature_flagged_transaction_for with project_id from single vulnerability' do
          expect(Vulnerability).to receive(:feature_flagged_transaction_for)
            .with([vulnerability.project]).and_call_original

          direct_reassign.send(:reassign_single_contribution, Vulnerability, vulnerability, 'author_id')

          expect(vulnerability.reload.author_id).to eq(reassign_to_user_id)
        end
      end

      context 'when batch update succeeds' do
        it 'updates all contributions in the batch' do
          create(:vulnerability, author_id: placeholder_user_id)
          create(:vulnerability, author_id: placeholder_user_id)

          direct_reassign.execute

          expect(Vulnerability.where(author_id: placeholder_user_id).count).to eq(0)
          expect(Vulnerability.where(author_id: reassign_to_user_id).count).to eq(3)
        end
      end
    end
  end

  describe '#direct_reassign_model_user_references' do
    context 'when reassigning Vulnerability model' do
      it 'executes the transaction block' do
        create(:vulnerability, author_id: placeholder_user_id)

        # Call the private method directly to test the transaction block
        direct_reassign.send(:direct_reassign_model_user_references, 'Vulnerability', 'author_id')

        expect(Vulnerability.where(author_id: placeholder_user_id).count).to eq(0)
        expect(Vulnerability.where(author_id: reassign_to_user_id).count).to eq(1)
      end
    end
  end

  describe '.model_list' do
    it 'includes expected models and their attributes' do
      model_list = described_class.model_list

      # EE models
      expect(model_list['ApprovalProjectRulesUser']).to eq(['user_id'])
      expect(model_list['BoardAssignee']).to eq(['assignee_id'])

      # CE models
      expect(model_list['Issue']).to eq(%w[author_id updated_by_id closed_by_id])
      expect(model_list['MergeRequest']).to eq(%w[author_id updated_by_id merge_user_id])
      expect(model_list['Note']).to eq(%w[author_id])
      expect(model_list['Approval']).to eq(['user_id'])
    end
  end
end
