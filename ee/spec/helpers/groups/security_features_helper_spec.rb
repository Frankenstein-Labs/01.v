# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SecurityFeaturesHelper, feature_category: :user_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:user) { create(:user) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
    allow(helper).to receive(:can?).and_return(false)

    allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?)
        .with(group)
        .and_return(false)
  end

  describe '#group_level_security_dashboard_available?' do
    where(:group_level_compliance_dashboard_enabled, :read_compliance_dashboard_permission, :result) do
      false | false | false
      true  | false | false
      false | true  | false
      true  | true  | true
    end

    with_them do
      before do
        stub_licensed_features(group_level_compliance_dashboard: group_level_compliance_dashboard_enabled)
        allow(helper).to receive(:can?).with(user, :read_compliance_dashboard, group).and_return(read_compliance_dashboard_permission)
      end

      it 'returns the expected result' do
        expect(helper.group_level_compliance_dashboard_available?(group)).to eq(result)
      end
    end
  end

  describe '#group_level_credentials_inventory_available?', :aggregate_failures, feature_category: :system_access do
    using RSpec::Parameterized::TableSyntax

    where(:group_owner?, :saas?, :licensed?, :result) do
      false | false | false | false
      false | false | false | false
      false | false | true  | false
      false | false | true  | false
      false | true  | false | false
      false | true  | false | false
      false | true  | true  | false
      false | true  | true  | false
      true  | false | false | false
      true  | false | false | false
      true  | false | true  | false
      true  | false | true  | false
      true  | true  | false | false
      true  | true  | false | false
      true  | true  | true  | true
    end

    subject { helper.group_level_credentials_inventory_available?(group) }

    with_them do
      before do
        access_level = group_owner? ? :owner : :maintainer
        group.add_member(user, access_level)
        stub_licensed_features(credentials_inventory: licensed?)
        allow(helper).to receive(:can?).with(user, :read_group_credentials_inventory, group).and_call_original
      end

      context 'for user', saas: params[:saas?] do
        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#group_level_security_dashboard_data' do
    subject { helper.group_level_security_dashboard_data(group) }

    before do
      allow(helper).to receive(:current_user).and_return(:user)
      allow(helper).to receive(:can?).and_return(true)
    end

    let(:has_projects) { 'false' }
    let(:dismissal_descriptions_json) do
      Gitlab::Json.parse(fixture_file('vulnerabilities/dismissal_descriptions.json', dir: 'ee')).to_json
    end

    let(:expected_data) do
      {
        projects_endpoint: "http://localhost/api/v4/groups/#{group.id}/projects",
        group_full_path: group.full_path,
        group_security_vulnerabilities_path: helper.group_security_vulnerabilities_path(group),
        no_vulnerabilities_svg_path: helper.image_path('illustrations/empty-state/empty-search-md.svg'),
        empty_state_svg_path: helper.image_path('illustrations/empty-state/empty-dashboard-md.svg'),
        security_dashboard_empty_svg_path: helper.image_path('illustrations/empty-state/empty-secure-md.svg'),
        vulnerabilities_export_endpoint: "/api/v4/security/groups/#{group.id}/vulnerability_exports",
        vulnerabilities_pdf_export_endpoint: "/api/v4/security/groups/#{group.id}/vulnerability_exports?export_format=pdf",
        can_admin_vulnerability: 'true',
        can_view_false_positive: 'false',
        has_projects: has_projects,
        dismissal_descriptions: dismissal_descriptions_json,
        show_retention_alert: 'false',
        manage_duo_settings_path: "/groups/#{group.full_path}/-/edit#js-gitlab-duo-settings",
        experiment_features_enabled: 'false',
        duo_agent_platform_available: 'false'
      }
    end

    context 'when it does not have projects' do
      it { is_expected.to eq(expected_data) }
    end

    context 'when it has projects' do
      let(:has_projects) { 'true' }

      before do
        create(:project, :public, group: group)
      end

      it { is_expected.to eq(expected_data) }
    end

    context 'when it does not have projects but has subgroups that do' do
      let(:subgroup) { create(:group, parent: group) }
      let(:has_projects) { 'true' }

      before do
        create(:project, :public, group: subgroup)
      end

      it { is_expected.to eq(expected_data) }
    end
  end

  describe '#group_level_security_inventory_data' do
    let_it_be(:group) { create(:group) }

    let(:expected_group_level_security_inventory_data) do
      {
        group_full_path: group.full_path,
        group_id: group.id,
        can_manage_attributes: 'false',
        can_read_attributes: 'false',
        can_apply_profiles: 'false',
        group_manage_attributes_path: group_security_configuration_path(group.root_ancestor, tab: 'attributes'),
        new_project_path: new_project_path(namespace_id: group.id)
      }
    end

    subject(:group_level_security_inventory_data) do
      helper.group_level_security_inventory_data(group)
    end

    it 'builds correct hash' do
      expect(group_level_security_inventory_data).to eq(expected_group_level_security_inventory_data)
    end
  end

  describe '#group_security_discover_data' do
    let_it_be(:group) { create(:group) }

    let(:content) { 'discover-group-security' }

    let(:expected_group_security_discover_data) do
      {

        link: {
          main: new_trial_registration_path(glm_source: 'gitlab.com', glm_content: content),
          secondary: group_billings_path(group.root_ancestor, source: content)
        }
      }
    end

    subject(:group_security_discover_data) do
      helper.group_security_discover_data(group)
    end

    it 'builds correct hash' do
      expect(group_security_discover_data).to eq(expected_group_security_discover_data)
    end
  end

  describe '#group_security_configuration_data' do
    let_it_be(:group) { create(:group) }

    subject(:group_security_configuration_data) do
      helper.group_security_configuration_data(group)
    end

    it 'builds correct hash' do
      expect(group_security_configuration_data).to eq({
        namespace_id: group.root_ancestor.id,
        group_id: group.id,
        group_full_path: group.full_path,
        group_name: group.name,
        security_inventory_path: group_security_inventory_path(group),
        can_read_attributes: 'false',
        can_manage_attributes: 'false',
        can_read_scan_profiles: 'false',
        can_apply_profiles: 'false'
      })
    end
  end
end
