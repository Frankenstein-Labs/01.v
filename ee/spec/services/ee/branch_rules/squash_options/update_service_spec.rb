# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::BranchRules::SquashOptions::UpdateService, feature_category: :source_code_management do
  describe 'ee #execute_on_branch_rule added through extension' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let(:squash_option) { ::Projects::BranchRules::SquashOption.squash_options['always'] }
    let(:current_user) { maintainer }

    subject(:execute) do
      described_class.new(branch_rule, user: current_user, params: { squash_option: squash_option }).execute
    end

    context 'when branch rule is a BranchRule' do
      let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }
      let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }

      context 'and the feature is available' do
        before do
          stub_licensed_features(branch_rule_squash_options: true)
        end

        context 'when there is a squash option' do
          let!(:existing_squash_option) do
            create(:branch_rule_squash_option, project: project, protected_branch: protected_branch)
          end

          it 'updates the squash option without creating a new record' do
            expect { execute }
              .to change { protected_branch.squash_option.reload.squash_option }.from('default_off').to('always')
              .and not_change { ::Projects::BranchRules::SquashOption.count }.from(1)

            expect(execute).to be_success
          end

          it 'returns the squash option in the payload' do
            expect(execute.payload).to eq(branch_rule.squash_option)
          end
        end

        context 'when there is no squash option' do
          it 'creates a squash option' do
            expect { execute }
              .to change { protected_branch.reload&.squash_option&.squash_option }.from(nil).to('always')
              .and change { ::Projects::BranchRules::SquashOption.count }.from(0).to(1)

            expect(execute).to be_success
          end

          it 'does not use nested attributes on the protected branch' do
            expect(protected_branch).not_to receive(:update)

            execute
          end
        end

        context 'when the squash option is invalid' do
          let_it_be(:protected_branch) { create(:protected_branch, project: project, name: '*') }

          it 'returns an error response with the validation messages', :aggregate_failures do
            expect(execute).to be_error
            expect(execute.message).to include(
              'Squash option cannot be used with wildcard branch rules. Use an exact branch name.'
            )
            expect(::Projects::BranchRules::SquashOption.count).to eq(0)
          end
        end
      end

      context 'and the feature is not available' do
        before do
          stub_licensed_features(branch_rule_squash_options: false)
        end

        it 'returns the feature not available error' do
          expect(execute).to be_error
          expect(execute.message).to eq('Squash options are not available for this branch rule')
        end
      end
    end

    context 'when branch rule is an AllProtectedBranchesRule' do
      let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

      before do
        stub_licensed_features(branch_rule_squash_options: true)
      end

      it 'returns a not supported error', :aggregate_failures do
        expect(execute).to be_error
        expect(execute.message).to eq('All protected branch rules cannot configure squash options')
        expect(execute.payload[:errors]).to contain_exactly('All protected branches not allowed')
        expect(execute.reason).to eq(:unprocessable_entity)
      end
    end
  end
end
