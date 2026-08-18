# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a ProjectSecurityExclusion', feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) do
    graphql_mutation(
      :project_security_exclusion_create,
      project_path: project.full_path,
      type: :RULE,
      scanner: :SECRET_PUSH_PROTECTION,
      value: 'gitlab_personal_access_token',
      description: 'Test exclusion',
      active: true
    )
  end

  let(:mutation_response) { graphql_mutation_response(:project_security_exclusion_create) }

  context 'when the feature is licensed for the project' do
    before do
      stub_licensed_features(security_exclusions: true)
    end

    context 'when the user can manage project security exclusions' do
      before_all do
        project.add_maintainer(current_user)
      end

      subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

      it 'creates a new project security exclusion' do
        request

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['securityExclusion']).to include(
          'id' => be_present,
          'type' => 'RULE',
          'scanner' => 'SECRET_PUSH_PROTECTION',
          'value' => 'gitlab_personal_access_token',
          'description' => 'Test exclusion',
          'active' => true
        )
      end

      it 'creates an audit event' do
        expect { request }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details[:custom_message])
          .to eq("Created a new security exclusion with type (rule)")
      end

      context 'when invalid arguments are used' do
        let(:mutation_with_long_value) do
          graphql_mutation(
            :project_security_exclusion_create,
            project_path: project.full_path,
            type: :RULE,
            value: 'a' * 256,
            scanner: :SECRET_PUSH_PROTECTION,
            description: 'Test exclusion',
            active: true
          )
        end

        it 'returns corresponding errors' do
          expect { post_graphql_mutation(mutation_with_long_value, current_user: current_user) }
            .not_to change { Security::ProjectSecurityExclusion.count }

          expect(mutation_response).to include(
            'securityExclusion' => nil,
            'errors' => ['Value is too long (maximum is 255 characters)']
          )
        end
      end
    end

    context 'when the user cannot manage project security exclusions' do
      before_all do
        project.add_developer(current_user)
      end

      it_behaves_like 'a mutation on an unauthorized resource'

      it 'does not create a new project security exclusion' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { Security::ProjectSecurityExclusion.count }
      end
    end

    context 'when the user is not authorized' do
      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when the feature is not licensed for the project' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
