# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Settings::SecureController, feature_category: :dependency_firewall do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:licensed_feature_available) { true }

  before do
    stub_licensed_features(dependency_firewall: licensed_feature_available)

    sign_in(user)
  end

  shared_examples 'renders 404' do
    it 'renders 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'GET /groups/:group_id/-/settings/secure' do
    subject(:request) { get group_settings_secure_path(group) }

    context 'when on GitLab.com', :saas_dependency_firewall do
      context 'and the user is a group owner' do
        before_all do
          group.add_owner(user)
        end

        it 'renders the page', :aggregate_failures do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to include('js-dependency-firewall-settings')
        end

        context 'when the dependency_firewall licensed feature is unavailable' do
          let(:licensed_feature_available) { false }

          it_behaves_like 'renders 404'
        end

        context 'when the dependency_firewall_phase1 feature flag is disabled' do
          before do
            stub_feature_flags(dependency_firewall_phase1: false)
          end

          it_behaves_like 'renders 404'
        end

        context 'when the group is a subgroup' do
          let_it_be(:subgroup) { create(:group, parent: group) }

          subject(:request) { get group_settings_secure_path(subgroup) }

          before_all do
            subgroup.add_owner(user)
          end

          it_behaves_like 'renders 404'
        end
      end

      context 'and the user is not a group admin' do
        before_all do
          group.add_maintainer(user)
        end

        it_behaves_like 'renders 404'
      end
    end

    context 'when not on GitLab.com' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'renders 404'
    end
  end

  describe 'PATCH /groups/:group_id/-/settings/secure', :saas_dependency_firewall do
    subject(:request) do
      patch group_settings_secure_path(group), params: { group: { dependency_firewall_enabled: true } }
    end

    context 'and the user is a group owner' do
      before_all do
        group.add_owner(user)
      end

      it 'updates the setting and redirects back to the secure settings page' do
        request

        expect(group.namespace_settings.reload.dependency_firewall_enabled).to be(true)
        expect(response).to redirect_to(
          group_settings_secure_path(group, anchor: 'js-dependency-firewall-settings')
        )
      end

      context 'when the dependency_firewall licensed feature is unavailable' do
        let(:licensed_feature_available) { false }

        it_behaves_like 'renders 404'
      end
    end

    context 'and the user is not a group admin' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'renders 404'
    end
  end
end
