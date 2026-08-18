# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::DependencyFirewallController, :saas_dependency_firewall,
  feature_category: :dependency_firewall do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:developer) { create(:user, developer_of: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }
  let_it_be(:non_member) { create(:user) }

  let(:current_user) { developer }

  before do
    stub_licensed_features(security_orchestration_policies: true, dependency_firewall: true)
    group.namespace_settings.update!(dependency_firewall_enabled: true)
    sign_in(current_user) if current_user
  end

  subject(:request_show) { get group_security_dependency_firewall_path(group) }

  shared_examples 'showing the dashboard' do
    it 'renders the dashboard', :aggregate_failures do
      request_show

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('js-dependency-firewall-dashboard')
    end
  end

  shared_examples 'hiding the dashboard' do
    it 'returns 404' do
      request_show

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'authorization' do
    context 'with a developer' do
      it_behaves_like 'showing the dashboard'
    end

    # Developer is the minimum role: widening the ability to Reporter or Guest
    # has to fail one of these two.
    context 'with a reporter' do
      let(:current_user) { reporter }

      it_behaves_like 'hiding the dashboard'
    end

    context 'with a guest' do
      let(:current_user) { guest }

      it_behaves_like 'hiding the dashboard'
    end

    context 'with a non-member' do
      let(:current_user) { non_member }

      it_behaves_like 'hiding the dashboard'
    end

    context 'with an anonymous user' do
      let(:current_user) { nil }

      it_behaves_like 'hiding the dashboard'
    end
  end

  describe 'availability' do
    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it_behaves_like 'hiding the dashboard'
    end

    context 'when the dependency firewall is not licensed' do
      before do
        stub_licensed_features(security_orchestration_policies: true, dependency_firewall: false)
      end

      it_behaves_like 'hiding the dashboard'
    end

    context 'when the dependency firewall is disabled for the group' do
      before do
        group.namespace_settings.update!(dependency_firewall_enabled: false)
      end

      it_behaves_like 'hiding the dashboard'
    end
  end
end
