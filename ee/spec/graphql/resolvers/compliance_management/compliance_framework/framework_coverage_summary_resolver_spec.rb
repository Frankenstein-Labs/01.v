# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceManagement::ComplianceFramework::FrameworkCoverageSummaryResolver,
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:framework) { create(:compliance_framework, namespace: group) }

  let_it_be(:active_project1) { create(:project, group: group) }
  let_it_be(:active_project2) { create(:project, group: group) }
  let_it_be(:archived_project) { create(:project, :archived, group: group) }
  let_it_be(:pending_deletion_project) { create(:project, group: group, marked_for_deletion_at: Date.current) }

  before_all do
    group.add_owner(current_user)
    create(:compliance_framework_project_setting, project: active_project1, compliance_management_framework: framework)
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  describe '#resolve' do
    subject(:result) { resolve(described_class, obj: group, ctx: { current_user: current_user }) }

    it 'returns coverage summary excluding archived and pending deletion projects' do
      expect(result).to eq({
        total_projects: 2,
        covered_count: 1
      })
    end

    context 'when archived project has framework' do
      before do
        create(:compliance_framework_project_setting,
          project: archived_project,
          compliance_management_framework: framework)
      end

      it 'does not count archived project in covered count' do
        expect(result[:covered_count]).to eq(1)
      end
    end

    context 'when pending deletion project has framework' do
      before do
        create(:compliance_framework_project_setting,
          project: pending_deletion_project,
          compliance_management_framework: framework)
      end

      it 'does not count pending deletion project in covered count' do
        expect(result[:covered_count]).to eq(1)
      end
    end

    context 'when group has no active projects' do
      let_it_be(:empty_group) { create(:group) }
      let_it_be(:empty_framework) { create(:compliance_framework, namespace: empty_group) }

      before_all do
        empty_group.add_owner(current_user)
      end

      subject(:result) { resolve(described_class, obj: empty_group, ctx: { current_user: current_user }) }

      it 'returns zero for both counts' do
        expect(result).to eq({
          total_projects: 0,
          covered_count: 0
        })
      end
    end
  end
end
