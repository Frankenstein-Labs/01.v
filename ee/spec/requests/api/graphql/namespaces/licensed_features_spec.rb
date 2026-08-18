# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'namespace.licensedFeatures', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group, developers: user) }

  let(:query) do
    graphql_query_for(
      :namespace,
      { full_path: namespace.full_path },
      query_graphql_field(:available_features, available_features_fields)
    )
  end

  let(:available_features_fields) do
    <<~FIELDS
      hasBlockedIssuesFeature
      hasCustomFieldsFeature
      hasEpicsFeature
      hasGroupBulkEditFeature
      hasIssuableHealthStatusFeature
      hasIssueDateFilterFeature
      hasIssueWeightsFeature
      hasIterationsFeature
      hasLinkedItemsEpicsFeature
      hasOkrsFeature
      hasQualityManagementFeature
      hasScopedLabelsFeature
      hasSubepicsFeature
      hasWorkItemStatusFeature
    FIELDS
  end

  context 'when features are available' do
    before do
      stub_feature_flags(issue_date_filter: true)
      stub_licensed_features(
        blocked_issues: true,
        custom_fields: true,
        epics: true,
        group_bulk_edit: true,
        issuable_health_status: true,
        issue_weights: true,
        iterations: true,
        linked_items_epics: true,
        okrs: true,
        quality_management: true,
        scoped_labels: true,
        subepics: true,
        work_item_status: true
      )
    end

    it 'returns true' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:namespace, :available_features)).to eq(
        'hasBlockedIssuesFeature' => true,
        'hasCustomFieldsFeature' => true,
        'hasEpicsFeature' => true,
        'hasGroupBulkEditFeature' => true,
        'hasIssuableHealthStatusFeature' => true,
        'hasIssueDateFilterFeature' => true,
        'hasIssueWeightsFeature' => true,
        'hasIterationsFeature' => true,
        'hasLinkedItemsEpicsFeature' => true,
        'hasOkrsFeature' => true,
        'hasQualityManagementFeature' => true,
        'hasScopedLabelsFeature' => true,
        'hasSubepicsFeature' => true,
        'hasWorkItemStatusFeature' => true
      )
    end
  end

  context 'when features are not available' do
    before do
      stub_feature_flags(issue_date_filter: false)
      stub_licensed_features(
        blocked_issues: false,
        custom_fields: false,
        epics: false,
        group_bulk_edit: false,
        issuable_health_status: false,
        issue_weights: false,
        iterations: false,
        linked_items_epics: false,
        okrs: false,
        quality_management: false,
        scoped_labels: false,
        subepics: false,
        work_item_status: false
      )
    end

    it 'returns false' do
      post_graphql(query, current_user: user)

      expect(graphql_data_at(:namespace, :available_features)).to eq(
        'hasBlockedIssuesFeature' => false,
        'hasCustomFieldsFeature' => false,
        'hasEpicsFeature' => false,
        'hasGroupBulkEditFeature' => false,
        'hasIssuableHealthStatusFeature' => false,
        'hasIssueDateFilterFeature' => false,
        'hasIssueWeightsFeature' => false,
        'hasIterationsFeature' => false,
        'hasLinkedItemsEpicsFeature' => false,
        'hasOkrsFeature' => false,
        'hasQualityManagementFeature' => false,
        'hasScopedLabelsFeature' => false,
        'hasSubepicsFeature' => false,
        'hasWorkItemStatusFeature' => false
      )
    end
  end
end
