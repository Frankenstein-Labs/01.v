# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::ComplianceDashboardsController, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET show' do
    subject { get :show, params: { group_id: group.to_param } }

    context 'when compliance dashboard feature is enabled' do
      before do
        stub_licensed_features(group_level_compliance_dashboard: true)
      end

      context 'and user is allowed to access group compliance dashboard' do
        before_all do
          group.add_owner(user)
        end

        it { is_expected.to have_gitlab_http_status(:success) }

        it_behaves_like 'tracking unique visits', :show do
          let(:request_params) { { group_id: group.to_param } }
          let(:target_id) { 'g_compliance_dashboard' }
        end

        it_behaves_like 'internal event tracking' do
          let(:namespace) { group }
          let(:event) { 'g_compliance_dashboard' }
          let(:label) { 'compliance_status' }
        end
      end

      context 'when user is not allowed to access group compliance dashboard' do
        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end

    context 'when compliance dashboard feature is disabled' do
      it { is_expected.to have_gitlab_http_status(:not_found) }
    end
  end

  describe '#additional_properties' do
    before do
      allow(controller).to receive(:compliance_tab).and_return('test_tab')
    end

    it 'returns a hash with label key' do
      expect(controller.additional_properties).to eq({ label: 'test_tab' })
    end
  end

  describe '#compliance_tab' do
    before do
      allow(controller).to receive(:vue_route).and_return(route)
    end

    where(:route, :expected_tab_result) do
      [
        # We renamed the new compliance report when we added the new version.
        # (standards_adherence => compliance_status)
        # The old default URL maps to the new dashboard.
        ['standards_adherence/some/path', 'compliance_status'],
        ['compliance_status/some/path', 'compliance_status'],
        ['', 'compliance_status'],
        ['violations/some/path', 'violations'],
        ['frameworks/some/path', 'frameworks'],
        ['projects/some/path', 'projects'],
        ['unknown/some/path', 'unknown_vue_tab_route'],
        ['777/snake/eyes', 'unknown_vue_tab_route']
      ]
    end

    with_them do
      it 'returns the expected compliance tab' do
        expect(controller.compliance_tab).to eq(expected_tab_result)
      end
    end
  end

  describe '#tracking_namespace_source' do
    it 'returns the group' do
      controller.instance_variable_set(:@group, group)

      expect(controller.tracking_namespace_source).to eq(group)
    end
  end

  describe '#tracking_project_source' do
    it 'returns nil' do
      expect(controller.tracking_project_source).to be_nil
    end
  end
end
