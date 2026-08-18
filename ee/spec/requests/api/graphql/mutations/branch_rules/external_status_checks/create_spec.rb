# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an external status check', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let(:branch_rule) { ::Projects::BranchRule.new(project, protected_branch) }
  let(:branch_rule_gid) { branch_rule.to_global_id.to_s }
  let(:status_check_name) { 'Test' }
  let(:external_url) { 'https://external_url.text/hello.json' }
  let(:params) { { branch_rule_id: branch_rule_gid, name: status_check_name, external_url: external_url } }
  let(:mutation) { graphql_mutation(:branch_rule_external_status_check_create, **params) }
  let(:mutation_response) { graphql_mutation_response(:branch_rule_external_status_check_create) }

  subject(:mutation_request) { post_graphql_mutation(mutation, current_user: current_user) }

  it_behaves_like 'authorizing granular token permissions for GraphQL', :create_external_status_check do
    let(:user) { create(:user, maintainer_of: project) }
    let(:boundary_object) { project }
    let(:request) do
      post_graphql_mutation(
        graphql_mutation(:branch_rule_external_status_check_create,
          { branch_rule_id: branch_rule.to_global_id.to_s, name: 'Test',
            external_url: 'https://external_url.text/hello.json' }, 'errors'),
        token: { personal_access_token: pat })
    end
  end

  shared_examples 'it expects value not to be null' do
    it 'returns error' do
      expect { mutation_request }.to not_change { MergeRequests::ExternalStatusCheck.count }

      error_message = graphql_errors[0]["extensions"]["problems"][0]["explanation"]
      expect(error_message).to eq('Expected value to not be null')
    end
  end

  context 'with invalid params' do
    context 'when the branch rule GID is nil' do
      let(:branch_rule_gid) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when an invalid global id is given' do
      let(:branch_rule_gid) { project.to_gid.to_s }
      let(:error_message) { %("#{branch_rule_gid}" does not represent an instance of Projects::BranchRule) }
      let(:global_id_error) { a_hash_including('message' => a_string_including(error_message)) }

      it 'returns an error' do
        expect { mutation_request }.to not_change { MergeRequests::ExternalStatusCheck.count }

        expect(graphql_errors).to include(global_id_error)
      end
    end

    context 'when there is no external url' do
      let(:external_url) { nil }

      it_behaves_like 'it expects value not to be null'
    end

    context 'when there is no name' do
      let(:status_check_name) { nil }

      it_behaves_like 'it expects value not to be null'
    end
  end

  context 'with valid params' do
    context 'when user is not authorized' do
      it 'returns error' do
        expect { mutation_request }.to not_change { MergeRequests::ExternalStatusCheck.count }

        expected_message = "you don't have permission to perform this action"
        expect(graphql_errors).to include(a_hash_including('message' => a_string_including(expected_message)))
      end
    end

    context 'when user is authorized' do
      before_all do
        project.add_maintainer(current_user)
      end

      it 'creates the external status check' do
        expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)

        expect(mutation_response['externalStatusCheck']['name']).to eq(status_check_name)
        expect(mutation_response['externalStatusCheck']['externalUrl']).to eq(external_url)
        expect(graphql_errors).to be_nil
      end

      context 'when shared_secret is provided' do
        let(:params) do
          { branch_rule_id: branch_rule_gid, name: status_check_name, external_url: external_url,
            shared_secret: 'test_secret_123' }
        end

        it 'creates the external status check with HMAC enabled' do
          expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)

          created_check = MergeRequests::ExternalStatusCheck.last
          expect(created_check).to have_attributes(name: status_check_name, external_url: external_url)
          expect(mutation_response['externalStatusCheck']['hmac']).to be(true)
          expect(graphql_errors).to be_nil
        end

        context 'when shared_secret exceeds maximum length' do
          let(:params) do
            { branch_rule_id: branch_rule_gid, name: status_check_name, external_url: external_url,
              shared_secret: 'a' * 256 }
          end

          it 'returns an error' do
            expect { mutation_request }.not_to change { MergeRequests::ExternalStatusCheck.count }

            expect(mutation_response['errors']).to include('Shared secret is too long (maximum is 255 characters)')
          end
        end
      end

      context 'when the service to create external checks fails' do
        before do
          allow_next_instance_of(MergeRequests::ExternalStatusCheck) do |instance|
            allow(instance).to receive(:save).and_raise('Error!')
          end
        end

        it 'returns an error' do
          expect { mutation_request }.to not_change { MergeRequests::ExternalStatusCheck.count }

          expect(graphql_errors).to include(a_hash_including('message' => a_string_including('Error!')))
        end
      end

      context 'when the branch rule is an Projects::AllBranchesRule' do
        let(:branch_rule) { ::Projects::AllBranchesRule.new(project) }

        it 'creates the external status check' do
          expect { mutation_request }.to change { MergeRequests::ExternalStatusCheck.count }.by(1)

          expect(mutation_response['externalStatusCheck']['name']).to eq(status_check_name)
          expect(mutation_response['externalStatusCheck']['externalUrl']).to eq(external_url)
          expect(graphql_errors).to be_nil
        end
      end

      context 'when the branch rule is a Projects::AllProtectedBranchesRule' do
        let(:branch_rule) { ::Projects::AllProtectedBranchesRule.new(project) }

        it 'returns an error' do
          expect { mutation_request }.to not_change { MergeRequests::ExternalStatusCheck.count }

          expect(mutation_response['errors']).to include('All protected branches not allowed')
          expect(graphql_errors).to be_nil
        end
      end
    end
  end
end
