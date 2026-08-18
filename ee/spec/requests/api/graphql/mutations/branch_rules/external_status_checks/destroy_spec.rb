# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy an external status check', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
  let(:external_status_check) do
    create(:external_status_check, project: project, protected_branches: [protected_branch])
  end

  let(:external_status_check_gid) { external_status_check.to_global_id.to_s }
  let(:branch_rule_gid) { branch_rule.to_global_id.to_s }

  let(:params) do
    {
      id: external_status_check_gid,
      branch_rule_id: branch_rule_gid
    }
  end

  let(:mutation) { graphql_mutation(:branch_rule_external_status_check_destroy, **params) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_external_status_check_destroy) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_external_status_check do
    let(:user) { create(:user, maintainer_of: project) }
    let(:boundary_object) { project }
    let(:request) do
      post_graphql_mutation(
        graphql_mutation(:branch_rule_external_status_check_destroy,
          { id: external_status_check.to_global_id.to_s, branch_rule_id: branch_rule.to_global_id.to_s }, 'errors'),
        token: { personal_access_token: pat })
    end
  end

  shared_examples 'it expects value not to be null' do
    it 'does not destroy the external status check record' do
      expect { mutation_request }.to not_change { external_status_check }
    end

    it 'returns an error message' do
      mutation_request

      expected_message = 'Expected value to not be null'
      expect(graphql_errors).to include(a_hash_including('message' => a_string_including(expected_message)))
    end
  end

  context 'with valid params' do
    context 'when user is not authorized' do
      it 'returns an error' do
        expect { mutation_request }.to not_change { external_status_check }

        expected_message = "you don't have permission to perform this action"
        expect(graphql_errors).to include(a_hash_including('message' => a_string_including(expected_message)))
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'destroys the external status check' do
        mutation_request

        expect { external_status_check.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(graphql_errors).to be_nil
      end

      context 'when the branch rule is an Projects::AllBranchesRule' do
        let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }
        let(:external_status_check) do
          create(:external_status_check, project: project, protected_branches: [])
        end

        it 'destroys the external status check' do
          mutation_request
          expect { external_status_check.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect(graphql_errors).to be_nil
        end
      end

      context 'when the branch rule is a Projects::AllProtectedBranchesRule' do
        let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }
        let(:external_status_check) do
          create(:external_status_check, project: project, protected_branches: [])
        end

        it 'returns an error' do
          mutation_request

          expect(mutation_response['errors']).to include('All protected branches not allowed')
          expect { external_status_check.reload }.not_to raise_error
          expect(graphql_errors).to be_nil
        end
      end

      context 'when the service to destroy external checks returns an error' do
        it 'does not destroy the external status check' do
          allow_next_found_instance_of(MergeRequests::ExternalStatusCheck) do |instance|
            allow(instance).to receive(:destroy).with(any_args).and_raise('Error!')
          end

          expect { mutation_request }.to not_change { external_status_check }

          expect(graphql_errors).to include(a_hash_including('message' => a_string_including('Error!')))
        end
      end
    end
  end

  context 'with invalid params' do
    context 'when the external_status_check GID is nil' do
      let(:external_status_check_gid) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when the branch_rule GID is nil' do
      let(:branch_rule_gid) { nil }

      it_behaves_like 'it expects value not to be null'
    end
  end

  context 'with invalid global ids given' do
    context 'when branch_rule GID is invalid' do
      let(:branch_rule_gid) { project.to_gid.to_s }
      let(:error_message) { %("#{branch_rule_gid}" does not represent an instance of Projects::BranchRule) }
      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error message' do
        expect { mutation_request }.to not_change { external_status_check }

        expect(graphql_errors).to include(global_id_error)
      end
    end

    context 'when external_check_rule GID is invalid' do
      let(:external_status_check_gid) { project.to_gid.to_s }

      let(:error_message) do
        %("#{external_status_check_gid}" does not represent an instance of MergeRequests::ExternalStatusCheck)
      end

      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error message' do
        expect { mutation_request }.to not_change { external_status_check }

        expect(graphql_errors).to include(global_id_error)
      end
    end
  end
end
