# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deleting a ProjectSecurityExclusion', feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:exclusion) { create(:project_security_exclusion, :with_path, :active, project: project) }

  let(:mutation) do
    graphql_mutation(:project_security_exclusion_delete, id: exclusion.to_global_id)
  end

  let(:mutation_response) { graphql_mutation_response(:project_security_exclusion_delete) }

  context 'when the user can manage project security exclusions' do
    before_all do
      project.add_maintainer(current_user)
    end

    context 'when the feature is licensed for the project' do
      before do
        stub_licensed_features(security_exclusions: true)
      end

      subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

      it 'destroys the project security exclusion' do
        expect { request }.to change { project.security_exclusions.reload.count }.by(-1)
        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
      end

      it 'creates an audit event' do
        expect { request }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details[:custom_message])
          .to eq("Deleted a security exclusion with type (path)")
      end

      context 'with an invalid global id' do
        let(:mutation) do
          graphql_mutation(
            :project_security_exclusion_delete,
            id: "gid://gitlab/Security::ProjectSecurityExclusion/#{non_existing_record_id}"
          )
        end

        before do
          post_graphql_mutation(mutation, current_user: current_user)
        end

        it_behaves_like 'a mutation on an unauthorized resource'
      end

      context 'when delete fails' do
        before do
          allow_next_instance_of(Mutations::Security::ProjectSecurityExclusionDelete) do |mutation|
            allow(mutation).to receive(:authorized_find!).and_return(exclusion)
          end

          allow(exclusion).to receive(:destroy).and_return(false)

          errors = ActiveModel::Errors.new(exclusion).tap { |e| e.add(:base, 'Exclusion could not be deleted.') }

          allow(exclusion).to receive(:errors).and_return(errors)
        end

        it 'returns an error' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ProjectSecurityExclusion.count }

          expect(mutation_response).to include(
            'errors' => ['Exclusion could not be deleted.']
          )
        end
      end
    end

    context 'when the feature is not licensed for the project' do
      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when the user cannot manage project security exclusions' do
    before_all do
      project.add_developer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'

    it 'does not destroy the project security exclusion' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }
        .to not_change { project.security_exclusions.reload.count }
    end
  end

  context 'when the user is not authorized' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
