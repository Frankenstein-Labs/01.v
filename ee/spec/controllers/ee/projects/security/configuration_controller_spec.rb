# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::ConfigurationController, feature_category: :security_testing_configuration do
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user) }

  before do
    allow(controller).to receive(:ensure_security_and_compliance_enabled!)
    allow(controller).to receive(:ensure_security_dashboard_feature_enabled!)
    allow(controller).to receive(:authorize_read_security_dashboard!)
    allow(controller).to receive(:add_gon_variables)

    sign_in(user)
  end

  describe 'GET show' do
    context 'when user has developer access' do
      before_all do
        project.add_developer(user)
      end

      it 'pushes security_scan_profiles_feature feature flag to the frontend' do
        allow(controller).to receive(:push_frontend_feature_flag)

        get :show, params: { namespace_id: project.namespace, project_id: project }

        expect(controller).to have_received(:push_frontend_feature_flag)
          .with(:security_scan_profiles_feature, project.root_ancestor).at_least(:once)
      end

      it 'pushes security_attributes licensed feature to the frontend' do
        allow(controller).to receive(:push_licensed_feature)

        get :show, params: { namespace_id: project.namespace, project_id: project }

        expect(controller).to have_received(:push_licensed_feature)
          .with(:security_attributes, project.root_ancestor)
      end

      it 'pushes security_scan_profiles_status_indicators feature flag to the frontend' do
        allow(controller).to receive(:push_frontend_feature_flag)

        get :show, params: { namespace_id: project.namespace, project_id: project }

        expect(controller).to have_received(:push_frontend_feature_flag)
          .with(:security_scan_profiles_status_indicators, project.root_ancestor)
      end
    end
  end
end
