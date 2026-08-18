# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectsController, :with_license, feature_category: :groups_and_projects do
  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- specs read Amazon Q instance settings stored on the default organization
  let_it_be(:user) { create(:user, :with_namespace) }
  let_it_be(:project) { create(:project, maintainers: user) }

  before do
    sign_in(user)
  end

  context 'when Amazon Q is connected' do
    let_it_be(:integration) { create(:amazon_q_integration, instance: false, project: project) }

    let(:params) do
      {
        project: {
          amazon_q_auto_review_enabled: true,
          project_setting_attributes: { duo_features_enabled: 'true' }
        }
      }
    end

    before do
      allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
    end

    it 'changes auto_review_enabled field of the integration' do
      expect { put project_url(project, params) }.to change {
        project.amazon_q_integration.reload.auto_review_enabled
      }.from(false).to(true)
    end
  end

  context 'when viewing the new page' do
    it 'is successful' do
      get new_project_url

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe 'PUT #transfer_personal' do
    let_it_be(:user_namespace) { create(:user_namespace) }
    let_it_be(:personal_project) { create(:project, namespace: user_namespace) }

    context 'when is a project owner' do
      let_it_be(:group) { create(:group) }

      before_all do
        personal_project.add_owner(user)
      end

      before do
        allow_next_instance_of(Groups::CreateService) do |instance|
          allow(instance).to receive(:execute).and_return(ServiceResponse.success(payload: { group: group }))
        end
      end

      context 'when transfer is successful' do
        before_all do
          group.add_owner(user)
        end

        it 'returns link to a new group and group name' do
          put project_transfer_personal_path(personal_project)

          expect(json_response['redirect_to']).to eq(group_billings_path(group))
          expect(json_response['group_name']).to eq(group.name)
        end
      end

      context 'when transfer is not successful' do
        it 'returns error message' do
          put project_transfer_personal_path(personal_project)

          expect(json_response['message']).to eq('Personal project cannot be transferred')
        end
      end
    end

    context 'when user does not have permission to change namespace' do
      before_all do
        personal_project.add_developer(user)
      end

      it 'denies access' do
        put project_transfer_personal_path(personal_project)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
