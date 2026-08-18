# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::BranchRules::SquashOptions::CreateService, feature_category: :source_code_management do
  describe '#execute' do
    let_it_be_with_reload(:protected_branch) { create(:protected_branch) }
    let_it_be_with_reload(:project) { protected_branch.project }
    let_it_be(:maintainer) { create(:user, maintainer_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }

    let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
    let(:current_user) { maintainer }
    let(:squash_option) { ::Projects::BranchRules::SquashOption.squash_options['always'] }

    subject(:execute) do
      described_class.new(branch_rule, user: current_user, params: { squash_option: squash_option }).execute
    end

    before do
      stub_licensed_features(branch_rule_squash_options: true)
    end

    context 'when the user is authorized' do
      it 'creates the squash option' do
        result = nil
        expect { result = execute }.to change { ::Projects::BranchRules::SquashOption.count }.by(1)

        expect(result).to be_success
        expect(result.payload.squash_option).to eq('always')
      end
    end

    context 'when the user is not authorized' do
      let(:current_user) { developer }

      it 'returns an error response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('Failed to create squash option')
      end

      it 'does not create a squash option' do
        expect { execute }.not_to change { ::Projects::BranchRules::SquashOption.count }
      end
    end

    context 'when the feature is not available' do
      before do
        stub_licensed_features(branch_rule_squash_options: false)
      end

      it 'returns a feature not available error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('Squash options are not available for this branch rule')
      end

      it 'does not create a squash option' do
        expect { execute }.not_to change { ::Projects::BranchRules::SquashOption.count }
      end
    end

    context 'when the branch rule is a wildcard' do
      let(:wildcard_branch) { create(:protected_branch, name: 'feature-*', project: project) }
      let(:branch_rule) { ::Projects::BranchRule.new(project, wildcard_branch) }

      it 'returns the validation error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to include(
          'Squash option cannot be used with wildcard branch rules. Use an exact branch name.'
        )
      end

      it 'does not create a squash option' do
        expect { execute }.not_to change { ::Projects::BranchRules::SquashOption.count }
      end
    end

    context 'when a squash option already exists' do
      before do
        create(:branch_rule_squash_option, project: project, protected_branch: protected_branch)
      end

      it 'returns an error and does not create a duplicate' do
        expect { execute }.not_to change { ::Projects::BranchRules::SquashOption.count }
        expect(execute).to be_error
      end
    end

    context 'when the branch rule is an AllBranchesRule' do
      let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

      it 'returns a not supported error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('Squash options for all branches can only be changed using the update mutation')
      end
    end
  end
end
