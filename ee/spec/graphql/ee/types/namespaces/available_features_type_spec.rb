# frozen_string_literal: true

require "spec_helper"

def all_features
  {
    has_blocked_issues_feature: :blocked_issues,
    has_custom_fields_feature: :custom_fields,
    has_epics_feature: :epics,
    has_group_bulk_edit_feature: :group_bulk_edit,
    has_issuable_health_status_feature: :issuable_health_status,
    has_issue_weights_feature: :issue_weights,
    has_iterations_feature: :iterations,
    has_linked_items_epics_feature: :linked_items_epics,
    has_okrs_feature: :okrs,
    has_quality_management_feature: :quality_management,
    has_scoped_labels_feature: :scoped_labels,
    has_subepics_feature: :subepics,
    has_work_item_status_feature: :work_item_status
  }
end

def user_excluded_features
  [
    :has_custom_fields_feature,
    :has_iterations_feature,
    :has_work_item_status_feature
  ]
end

def user_features
  all_features.except(*user_excluded_features)
end

RSpec.describe Types::Namespaces::AvailableFeaturesType, feature_category: :shared do
  include GraphqlHelpers

  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { create(:group) }

  shared_examples_for 'tests feature availability' do |features|
    features.each do |field, licensed_feature|
      context "for #{field}" do
        describe 'when the feature is enabled' do
          before do
            stub_licensed_features(licensed_feature => true)
          end

          it 'returns true' do
            expect(resolve_field(field, namespace, current_user: user)).to be(true)
          end
        end

        describe 'when the feature is disabled' do
          before do
            stub_licensed_features(licensed_feature => false)
          end

          it 'returns false' do
            expect(resolve_field(field, namespace, current_user: user)).to be(false)
          end
        end
      end
    end
  end

  shared_examples_for 'a type that resolves available features' do
    it_behaves_like 'tests feature availability', all_features
  end

  shared_examples_for 'a type that resolves available user features' do
    it_behaves_like 'tests feature availability', user_features
  end

  context 'with a group namespace' do
    let_it_be(:namespace) { group }

    it_behaves_like 'a type that resolves available features'
  end

  context 'with a project namespace that belongs to a group' do
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:namespace) { project.project_namespace }

    it_behaves_like 'a type that resolves available features'
  end

  context 'with a project namespace that belongs to a user' do
    let_it_be(:namespace) { create(:project_namespace) }

    it_behaves_like 'a type that resolves available user features'
  end

  context 'with a user namespace' do
    let_it_be(:namespace) { create(:user_namespace) }

    it_behaves_like 'a type that resolves available user features'
  end

  it_behaves_like 'expose all available feature fields for the namespace'
end
