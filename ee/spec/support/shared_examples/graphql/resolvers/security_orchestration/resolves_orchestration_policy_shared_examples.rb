# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'as an orchestration policy' do
  include Security::PolicyCspHelpers

  let!(:policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: project
    )
  end

  let(:repository) { instance_double(Repository, root_ref: 'master', empty?: false) }

  before do
    commit = create(:commit)
    commit.committed_date = policy_last_updated_at
    allow(policy_management_project).to receive(:repository).and_return(repository)
    allow(repository).to receive(:last_commit_for_path).and_return(commit)
    allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
  end

  describe '#resolve' do
    context 'when feature is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: false)
        project.add_developer(user)
      end

      it 'returns empty collection' do
        is_expected.to be_empty
      end
    end

    context 'when feature is licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true)
      end

      context 'when user is authorized' do
        before do
          project.add_developer(user)
        end

        it 'returns the policies' do
          is_expected.to eq(expected_resolved.map { |obj| obj.merge(csp: false) })
        end

        context 'when the configuration belongs to a CSP group' do
          subject(:resolve_policies) { resolve(described_class, obj: group, ctx: { current_user: user }) }

          let_it_be(:group, freeze: false) { create(:group, developers: [user]) }
          let!(:policy_configuration) do
            create(:security_orchestration_policy_configuration, :namespace,
              namespace: group,
              security_policy_management_project: policy_management_project)
          end

          before do
            stub_csp_group(group)
          end

          it 'returns the policies with csp: true' do
            expect(resolve_policies).to match array_including(hash_including(csp: true))
          end
        end
      end

      context 'when user is unauthorized' do
        it 'returns empty collection' do
          is_expected.to be_empty
        end
      end
    end
  end
end
