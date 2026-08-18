# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DashboardController, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }

  describe 'GET #show' do
    subject(:show_security_dashboard) { get :show }

    it_behaves_like Security::ApplicationController do
      let(:security_application_controller_child_action) do
        get :show
      end
    end

    context 'when security dashboard feature' do
      before do
        sign_in(user)
      end

      context 'is enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it { is_expected.to render_template(:instance_security) }

        it_behaves_like 'internal event tracking' do
          let(:event) { 'visit_security_center' }
          let(:category) { described_class.name }
          subject(:service_action) { show_security_dashboard }
        end
      end

      context 'is disabled' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
        it { is_expected.to render_template('errors/not_found') }

        it 'does not record events or metrics' do
          expect { show_security_dashboard }
          .to not_trigger_internal_events('visit_security_center')
        end
      end
    end
  end
end
