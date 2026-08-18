# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'view audit events', feature_category: :audit_events do
  include AdminModeHelper

  describe 'GET /audit_events' do
    let_it_be(:admin) { create(:admin) }
    let_it_be(:new_user_audit_event) { create(:audit_events_user_audit_event) }
    let_it_be(:new_project_audit_event) { create(:audit_events_project_audit_event) }
    let_it_be(:new_group_audit_event) { create(:audit_events_group_audit_event) }
    let_it_be(:new_instance_audit_event) { create(:audit_events_instance_audit_event) }

    before do
      stub_licensed_features(admin_audit_log: true)
      login_as(admin)
    end

    context 'when admin mode is enabled' do
      before do
        enable_admin_mode!(admin)
      end

      it 'returns 200 response' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'displays audit events from new tables' do
        send_request

        expect(response.body).to include(new_user_audit_event.id.to_s)
        expect(response.body).to include(new_project_audit_event.id.to_s)
        expect(response.body).to include(new_group_audit_event.id.to_s)
        expect(response.body).to include(new_instance_audit_event.id.to_s)
      end

      context 'with active frameworks' do
        let_it_be(:group) { create(:group) }
        let_it_be(:framework) { create :compliance_framework, namespace_id: group.id }
        let_it_be(:project) { create :project, namespace: group }

        it 'returns 200 response' do
          create(:compliance_framework_project_setting, project: project, compliance_management_framework: framework)
          send_request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      it 'avoids N+1 DB queries', :request_store do
        # warm up cache so these initial queries would not leak in our QueryRecorder
        send_request

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { send_request }

        create_list(:audit_events_user_audit_event, 2)

        expect do
          send_request
        end.not_to exceed_all_query_limit(control)
      end
    end

    context 'when admin mode is disabled' do
      it 'redirects to admin mode enable' do
        send_request

        expect(response).to redirect_to(new_admin_session_path)
      end
    end

    def send_request
      get admin_audit_logs_path
    end
  end
end
