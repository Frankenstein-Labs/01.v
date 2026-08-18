# frozen_string_literal: true

require 'spec_helper'

# FIXME: feature_category is fixed but this test covers integrations that
# are owned by different groups
RSpec.describe Projects::Settings::IntegrationsController, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- See above
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, maintainers: user) }

  before do
    sign_in(user)
  end

  shared_examples 'endpoint with some disabled integrations' do
    it 'has some disabled integrations' do
      get :index, params: { namespace_id: project.namespace, project_id: project }

      expect(active_services).not_to include(*disabled_integrations)
    end
  end

  shared_examples 'endpoint without disabled integrations' do
    it 'does not have disabled integrations' do
      get :index, params: { namespace_id: project.namespace, project_id: project }

      expect(active_services).to include(*disabled_integrations)
    end
  end

  context 'sets correct services list' do
    let(:active_services) { assigns(:integrations).map(&:model_name) }
    let(:disabled_integrations) { %w[Integrations::Github] }

    context 'without a license key' do
      it_behaves_like 'endpoint with some disabled integrations'
    end

    context 'with a license key' do
      let_it_be(:namespace) { create(:group, :private) }
      let_it_be(:project) { create(:project, :private, namespace: namespace, maintainers: user) }

      before do
        create(:license, plan: ::License::PREMIUM_PLAN)
      end

      context 'when checking if namespace plan is enabled' do
        before do
          stub_application_setting(check_namespace_plan: true)
        end

        it_behaves_like 'endpoint with some disabled integrations'
      end

      context 'when checking if namespace plan is not enabled' do
        before do
          stub_application_setting(check_namespace_plan: false)
        end

        it_behaves_like 'endpoint without disabled integrations'
      end
    end
  end

  describe 'PUT #update' do
    let(:params) do
      {
        namespace_id: project.namespace,
        project_id: project,
        id: integration.to_param,
        service: integration_params
      }
    end

    let_it_be(:jira_integration) { create(:jira_integration, project: project) }
    let_it_be_with_reload(:integration) { jira_integration }

    before do
      put :update, params: params
    end

    context 'with project_keys in params' do
      let(:integration_params) { { project_keys: 'GTL,JR' } }

      it 'saves the project_keys as an array' do
        expect(integration.project_keys).to eq %w[GTL JR]
      end
    end
  end
end
