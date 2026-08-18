# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Statistics, 'Statistics', :aggregate_failures, feature_category: :devops_reports do
  describe 'GET /application/statistics' do
    let_it_be(:user) { create(:user) }

    subject(:get_statistics) do
      get api('/application/statistics', user)
      response
    end

    context 'when user is assigned a custom admin role' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      MemberRole.all_customizable_admin_permission_keys.each do |ability|
        context "with #{ability} ability" do
          before do
            create(:admin_member_role, ability, user: user)
          end

          context 'when application setting :admin_mode is enabled' do
            before do
              stub_application_setting(admin_mode: true)
            end

            context 'when admin mode is on', :enable_admin_mode do
              it { is_expected.to have_gitlab_http_status(:success) }
            end

            context 'when admin mode is off' do
              it { is_expected.to have_gitlab_http_status(:forbidden) }
            end
          end

          context 'when application setting :admin_mode is disabled' do
            before do
              stub_application_setting(admin_mode: false)
            end

            it { is_expected.to have_gitlab_http_status(:success) }
          end
        end
      end
    end

    context 'when user can not access admin area' do
      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end
  end
end
