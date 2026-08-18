# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::BranchRules::SquashOptions::DestroyService, feature_category: :source_code_management do
  describe '#execute' do
    let_it_be_with_reload(:protected_branch) { create(:protected_branch) }
    let_it_be(:project) { protected_branch.project }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }

    let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
    let(:current_user) { maintainer }

    subject(:execute) { described_class.new(branch_rule, user: current_user).execute }

    before do
      stub_licensed_features(branch_rule_squash_options: true)
    end

    context 'when there is a squash option' do
      let!(:squash_option) do
        create(:branch_rule_squash_option, project: project, protected_branch: protected_branch)
      end

      it 'deletes the squash option', :aggregate_failures do
        expect { execute }
          .to change { ::Projects::BranchRules::SquashOption.count }.from(1).to(0)

        expect(execute).to be_success
      end

      context 'and the user is not authorized' do
        let(:current_user) { developer }

        it 'returns an access denied error', :aggregate_failures do
          expect(execute).to be_error
          expect(execute.message).to eq('Failed to delete squash option')
          expect(execute.payload[:errors]).to contain_exactly('Not allowed')
          expect(execute.reason).to eq(:access_denied)
        end

        it 'does not delete the squash option' do
          expect { execute }.not_to change { ::Projects::BranchRules::SquashOption.count }.from(1)
        end
      end

      context 'and the feature is not available' do
        before do
          stub_licensed_features(branch_rule_squash_options: false)
        end

        it 'returns a feature not available error', :aggregate_failures do
          expect(execute).to be_error
          expect(execute.message).to eq('Squash options are not available for this branch rule')
        end

        it 'does not delete the squash option' do
          expect { execute }.not_to change { ::Projects::BranchRules::SquashOption.count }.from(1)
        end
      end
    end

    context 'when there is no squash option' do
      it 'returns a not found error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('Record not found')
        expect(execute.payload[:errors]).to contain_exactly('Not found')
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'when branch rule is an AllBranchesRule' do
      let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

      it 'returns a not supported error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('Deleting on an all branches rule is not supported')
      end
    end

    context 'when branch rule is an AllProtectedBranchesRule' do
      let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

      it 'returns a not supported error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('All protected branch rules cannot configure squash options')
        expect(execute.payload[:errors]).to contain_exactly('All protected branches not allowed')
        expect(execute.reason).to eq(:unprocessable_entity)
      end
    end
  end
end
