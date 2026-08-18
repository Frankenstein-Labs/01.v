# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CustomDashboards::Dashboard, feature_category: :custom_dashboards_foundation do
  let(:user) { create(:user) }
  let(:namespace) { create(:namespace) }
  let(:organization) { create(:organization) }

  let(:valid_config) do
    {
      version: "2",
      title: "Test Dashboard",
      description: "Test description",
      panels: [
        {
          title: "Test Panel",
          visualization: "number",
          gridAttributes: { width: 4, height: 2 }
        }
      ]
    }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace).optional }
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:created_by).class_name('User').required }
    it { is_expected.to belong_to(:updated_by).class_name('User').optional }
    it { is_expected.to have_one(:search_data) }
    it { is_expected.to have_many(:dashboard_versions).class_name('Analytics::CustomDashboards::DashboardVersion') }
  end

  describe 'validations' do
    subject { build(:dashboard, created_by: user, name: 'Dashboard', config: valid_config) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(2048) }
    it { is_expected.to validate_presence_of(:config) }

    it 'validates config is a JSON object' do
      dashboard = build(:dashboard, created_by: user, config: 'not a hash')
      expect(dashboard).not_to be_valid
      expect(dashboard.errors[:config]).to include('must be a JSON object')
    end

    describe 'inline panel visualizations' do
      let(:valid_visualization) do
        {
          version: 1,
          type: "LineChart",
          options: { xAxis: { name: "Time", type: "time" } },
          data: { type: "glql", query: { glql: "type = Issue" } }
        }
      end

      def build_with_visualization(visualization)
        config = {
          version: "2",
          title: "Test Dashboard",
          panels: [
            { title: "Panel", visualization: visualization, gridAttributes: { width: 4, height: 2 } }
          ]
        }

        build(:dashboard, created_by: user, config: config)
      end

      it 'is valid when the visualization is a string reference' do
        expect(build_with_visualization("number")).to be_valid
      end

      it 'is valid when the visualization is a schema-compliant config object' do
        expect(build_with_visualization(valid_visualization)).to be_valid
      end

      it 'is invalid when the visualization config object does not match the schema' do
        dashboard = build_with_visualization(valid_visualization.merge(type: "NotAChartType"))

        expect(dashboard).not_to be_valid
        expect(dashboard.errors[:config].join).to match(/must be a valid json schema/)
      end

      it 'is invalid when the visualization config object has unknown keys' do
        dashboard = build_with_visualization(valid_visualization.merge(unexpected: "value"))

        expect(dashboard).not_to be_valid
        expect(dashboard.errors[:config].join).to match(/must be a valid json schema/)
      end

      it 'is valid when all inline visualizations nested within panel views are schema-compliant' do
        config = {
          version: "2",
          title: "Test Dashboard",
          panels: [
            {
              title: "Panel",
              visualization: "number",
              gridAttributes: { width: 4, height: 2 },
              views: [
                { text: "A", visualization: valid_visualization },
                { text: "B", visualization: valid_visualization }
              ]
            }
          ]
        }

        dashboard = build(:dashboard, created_by: user, config: config)

        expect(dashboard).to be_valid
      end

      it 'is invalid when an inline visualization nested within a panel view does not match the schema' do
        config = {
          version: "2",
          title: "Test Dashboard",
          panels: [
            {
              title: "Panel",
              visualization: "number",
              gridAttributes: { width: 4, height: 2 },
              views: [
                { text: "A", visualization: valid_visualization },
                { text: "B", visualization: valid_visualization.merge(type: "NotAChartType") }
              ]
            }
          ]
        }

        dashboard = build(:dashboard, created_by: user, config: config)

        expect(dashboard).not_to be_valid
        expect(dashboard.errors[:config].join).to match(/must be a valid json schema/)
      end
    end
  end

  describe 'scopes' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:namespace1) { create(:group) }
    let_it_be(:namespace2) { create(:group) }
    let_it_be(:user1) { create(:user) }
    let_it_be(:user2) { create(:user) }

    let_it_be(:org_dashboard1) do
      create(:dashboard, organization: organization, namespace: nil, created_by: user1)
    end

    let_it_be(:org_dashboard2) do
      create(:dashboard, organization: organization, namespace: nil, created_by: user2)
    end

    let_it_be(:namespace_dashboard1) do
      create(:dashboard, organization: organization, namespace: namespace1, created_by: user1)
    end

    let_it_be(:namespace_dashboard2) do
      create(:dashboard, organization: organization, namespace: namespace2, created_by: user1)
    end

    describe '.by_namespace' do
      it 'returns dashboards for the given namespace' do
        expect(described_class.by_namespace(namespace1.id)).to contain_exactly(namespace_dashboard1)
      end
    end

    describe '.by_created_by' do
      it 'returns dashboards created by the given user' do
        expect(described_class.by_created_by(user1.id)).to contain_exactly(
          org_dashboard1,
          namespace_dashboard1,
          namespace_dashboard2
        )
      end
    end

    describe '.order_by_created_at_desc' do
      it 'orders dashboards by created_at in descending order' do
        dashboards = described_class.where(organization: organization).order_by_created_at_desc
        expect(dashboards.first.created_at).to be >= dashboards.last.created_at
      end
    end

    describe '.with_namespace' do
      it 'returns only dashboards with a namespace' do
        expect(described_class.with_namespace).to contain_exactly(
          namespace_dashboard1,
          namespace_dashboard2
        )
      end

      it 'excludes organization-scoped dashboards' do
        expect(described_class.with_namespace).not_to include(org_dashboard1, org_dashboard2)
      end
    end

    describe '#system?' do
      let(:dashboard) { build(:dashboard) }

      subject { dashboard.system? }

      it { is_expected.to be(false) }
    end

    describe '#slug' do
      let(:dashboard) { build(:dashboard) }

      subject { dashboard.slug }

      it { is_expected.to be_nil }
    end

    describe '.org_scoped' do
      let_it_be(:other_organization) { create(:organization) }

      let_it_be(:other_org_dashboard) do
        create(:dashboard,
          organization: other_organization,
          namespace: nil,
          created_by: user1
        )
      end

      it 'returns only organization-scoped dashboards for the given organization' do
        dashboards = described_class.org_scoped(organization.id)

        expect(dashboards).to contain_exactly(
          org_dashboard1,
          org_dashboard2
        )
      end

      it 'does not return dashboards from other organizations' do
        dashboards = described_class.org_scoped(organization.id)

        expect(dashboards).not_to include(other_org_dashboard)
      end
    end

    describe '.namespace_scoped' do
      context 'with a single namespace ID' do
        it 'returns dashboards in the specified namespace for the given organization' do
          dashboards = described_class
            .namespace_scoped(organization.id, [namespace1.id])

          expect(dashboards).to contain_exactly(namespace_dashboard1)
        end
      end

      context 'with multiple namespace IDs' do
        it 'returns dashboards in the specified namespaces for the given organization' do
          dashboards = described_class
            .namespace_scoped(organization.id, [namespace1.id, namespace2.id])

          expect(dashboards).to contain_exactly(
            namespace_dashboard1,
            namespace_dashboard2
          )
        end
      end
    end

    describe '.search_by_name' do
      let_it_be(:sales_dashboard) do
        create(:dashboard, organization: organization, namespace: nil, created_by: user1, name: 'Sales Dashboard')
      end

      let_it_be(:marketing_dashboard) do
        create(:dashboard, organization: organization, namespace: nil, created_by: user1, name: 'Marketing Dashboard')
      end

      it 'returns dashboards matching the search term' do
        expect(described_class.search_by_name('Sales')).to contain_exactly(sales_dashboard)
      end

      it 'does not return dashboards that do not match the search term' do
        expect(described_class.search_by_name('Sales')).not_to include(marketing_dashboard)
      end

      it 'returns empty result when no dashboards match' do
        expect(described_class.search_by_name('Nonexistent')).to be_empty
      end

      it 'is case insensitive' do
        expect(described_class.search_by_name('sales')).to contain_exactly(sales_dashboard)
      end

      it 'matches partial words via stemming' do
        expect(described_class.search_by_name('Market')).to contain_exactly(marketing_dashboard)
      end
    end
  end

  describe 'callbacks' do
    it 'creates a search data row after create' do
      dashboard = create(:dashboard, created_by: user, config: valid_config)
      dashboard.reload

      search_data = Analytics::CustomDashboards::SearchData.find_by(
        custom_dashboard_id: dashboard.id
      )
      expect(search_data).to be_present
    end

    it 'creates a new version when config changes' do
      dashboard = create(:dashboard, created_by: user, config: valid_config)

      updated_config = {
        version: "2",
        title: "Updated Dashboard",
        description: "Updated description",
        panels: [
          {
            title: "Updated Panel",
            visualization: "chart",
            gridAttributes: { width: 6, height: 3 }
          }
        ]
      }

      expect { dashboard.update!(config: updated_config) }.to change {
        dashboard.dashboard_versions.count
      }.by(1)

      version = dashboard.dashboard_versions.last
      expect(version.version_number).to eq(1)
      expect(version.config).to eq(updated_config.deep_stringify_keys)
    end

    it 'does not create a version if config did not change' do
      dashboard = create(:dashboard, created_by: user, config: valid_config)
      expect { dashboard.update!(name: 'Updated Name') }.not_to change { dashboard.dashboard_versions.count }
    end
  end

  describe '#create_config_version' do
    let(:dashboard) do
      create(:dashboard,
        created_by: user,
        updated_by: user,
        organization: organization,
        config: valid_config
      )
    end

    context 'when no previous version exists' do
      it 'creates version 1' do
        version = dashboard.send(:create_config_version)

        expect(version.version_number).to eq(1)
        expect(version.organization_id).to eq(dashboard.organization_id)
        expect(version.config).to eq(valid_config.deep_stringify_keys)
        expect(version.updated_by_id).to eq(user.id)
      end
    end

    context 'when a previous version exists' do
      before do
        create(:dashboard_version,
          dashboard: dashboard,
          organization_id: dashboard.organization_id,
          version_number: 1,
          config: valid_config
        )
      end

      it 'increments version number' do
        version = dashboard.send(:create_config_version)

        expect(version.version_number).to eq(2)
        expect(version.organization_id).to eq(dashboard.organization_id)
        expect(version.config).to eq(valid_config.deep_stringify_keys)
        expect(version.updated_by_id).to eq(user.id)
      end
    end
  end

  describe '.authorized_namespace_ids_for' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:user) { create(:user) }

    let_it_be(:authorized_group) { create(:group, organization: organization) }
    let_it_be(:authorized_subgroup) { create(:group, parent: authorized_group, organization: organization) }
    let_it_be(:unauthorized_group) { create(:group, organization: organization) }
    let_it_be(:other_org_group) { create(:group, organization: other_organization) }

    let_it_be(:authorized_member) do
      create(:group_member, :reporter, group: authorized_group, user: user)
    end

    let_it_be(:guest_member) do
      create(:group_member, :guest, group: unauthorized_group, user: user)
    end

    let_it_be(:other_org_member) do
      create(:group_member, :maintainer, group: other_org_group, user: user)
    end

    it 'returns namespace IDs where user has at least reporter access' do
      result = described_class.authorized_namespace_ids_for(user, organization: organization)

      expect(result).to contain_exactly(authorized_group.id, authorized_subgroup.id)
    end

    it 'includes descendant namespaces' do
      result = described_class.authorized_namespace_ids_for(user, organization: organization)

      expect(result).to include(authorized_subgroup.id)
    end

    it 'excludes namespaces below reporter access level' do
      result = described_class.authorized_namespace_ids_for(user, organization: organization)

      expect(result).not_to include(unauthorized_group.id)
    end

    it 'excludes namespaces from other organizations' do
      result = described_class.authorized_namespace_ids_for(user, organization: organization)

      expect(result).not_to include(other_org_group.id)
    end

    it 'returns empty array when user is nil' do
      result = described_class.authorized_namespace_ids_for(nil, organization: organization)

      expect(result).to be_empty
    end

    context 'when user has access to many namespaces' do
      it 'limits results to MAX_NAMESPACE_IDS' do
        stub_const("#{described_class}::MAX_NAMESPACE_IDS", 2)

        result = described_class.authorized_namespace_ids_for(user, organization: organization)

        expect(result.size).to eq(2)
      end
    end
  end
end
