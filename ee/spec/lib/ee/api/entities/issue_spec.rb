# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::Issue, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:project_issue) { create(:issue, project: project) }
  let_it_be(:group_issue) { create(:issue, :group_level, namespace: group) }

  let(:user_namespace_issue) { build_stubbed(:issue, :user_namespace_level) }
  let(:options) { { current_user: current_user }.merge(option_addons) }
  let(:option_addons) { {} }
  let(:entity) { described_class.new(issue, options) }

  let(:expected_attributes) do
    [
      :id, :iid, :project_id, :title, :description, :state, :created_at, :updated_at, :closed_at,
      :closed_by, :labels, :milestone, :assignees, :author, :type, :assignee, :user_notes_count,
      :merge_requests_count, :upvotes, :downvotes, :due_date, :confidential, :discussion_locked,
      :issue_type, :web_url, :time_stats, :task_completion_status, :weight, :blocking_issues_count,
      :has_tasks, :task_status, :_links, :references, :severity, :subscribed, :moved_to_id,
      :imported, :imported_from, :service_desk_reply_to, :iteration, :start_date
    ]
  end

  subject(:issue_json) { entity.as_json.keys }

  context 'with project issue' do
    let(:issue) { project_issue }

    it { is_expected.to contain_exactly(*expected_attributes) }
  end

  context 'with group issue' do
    let(:issue) { group_issue }

    it { is_expected.to contain_exactly(*expected_attributes) }
  end

  context 'with user namespace issue' do
    let(:issue) { user_namespace_issue }

    it { is_expected.to contain_exactly(*expected_attributes - [:iteration]) }
  end

  context 'with licensed feature checks' do
    using RSpec::Parameterized::TableSyntax

    context 'when including licensed attributes' do
      where(:issue, :licensed_feature, :license_enabled, :attributes) do
        ref(:project_issue)        | :epics                  | true | [:epic_iid, :epic]
        ref(:group_issue)          | :epics                  | true | [:epic_iid, :epic]
        ref(:project_issue)        | :iterations             | true | [:iteration]
        ref(:group_issue)          | :iterations             | true | [:iteration]
        ref(:project_issue)        | :issuable_health_status | true | [:health_status]
        ref(:group_issue)          | :issuable_health_status | true | [:health_status]
        ref(:user_namespace_issue) | :issuable_health_status | true | [:health_status]
      end

      with_them do
        before do
          stub_licensed_features("#{licensed_feature}": license_enabled)
        end

        it { is_expected.to include(*attributes) }
      end
    end

    context 'when excluding licensed attributes' do
      where(:issue, :licensed_feature, :license_enabled, :attributes) do
        ref(:project_issue)        | :epics                  | false | [:epic_iid, :epic]
        ref(:group_issue)          | :epics                  | false | [:epic_iid, :epic]
        ref(:user_namespace_issue) | :epics                  | true  | [:epic_iid, :epic]
        ref(:user_namespace_issue) | :epics                  | false | [:epic_iid, :epic]
        ref(:project_issue)        | :iterations             | false | [:iteration]
        ref(:group_issue)          | :iterations             | false | [:iteration]
        ref(:user_namespace_issue) | :iterations             | true  | [:iteration]
        ref(:user_namespace_issue) | :iterations             | false | [:iteration]
        ref(:project_issue)        | :issuable_health_status | false | [:health_status]
        ref(:group_issue)          | :issuable_health_status | false | [:health_status]
        ref(:user_namespace_issue) | :issuable_health_status | false | [:health_status]
      end

      with_them do
        before do
          stub_licensed_features("#{licensed_feature}": license_enabled)
        end

        it { is_expected.to exclude(*attributes) }
      end
    end
  end
end
