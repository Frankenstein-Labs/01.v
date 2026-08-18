# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, '#confidentiality', feature_category: :global_search do
  include SearchResultHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'confidentiality', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'for ConfidentialityWorkItemsTable context'

    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group) }

    let(:projects) { [project] }
    let(:search_level) { group }
    let_it_be(:term) { 'hello' }
    let(:search) { term }

    context 'for issues' do
      let(:scope) { 'issues' }

      let_it_be(:non_confidential) { create :work_item, project: project, title: term }
      let_it_be(:confidential) { create(:work_item, :confidential, title: term, project: project) }
      let_it_be_with_reload(:confidential_user_as_assignee) do
        create(:work_item, :confidential, title: term, project: project)
      end

      let_it_be_with_reload(:confidential_user_as_author) do
        create(:work_item, :confidential, title: term, project: project)
      end

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        confidentiality_table_for_work_item_access
      end

      with_them do
        it_behaves_like 'search respects confidentiality'
      end
    end

    context 'for epics' do
      let(:scope) { 'epics' }

      let_it_be(:non_confidential) do
        create :work_item, :group_level, :epic_with_legacy_epic, namespace: group, title: term
      end

      let_it_be(:confidential) do
        create(:work_item, :confidential, :group_level, :epic_with_legacy_epic, namespace: group, title: term)
      end

      let_it_be_with_reload(:confidential_user_as_assignee) do
        create(:work_item, :confidential, :group_level, :epic_with_legacy_epic, namespace: group, title: term)
      end

      let_it_be_with_reload(:confidential_user_as_author) do
        create(:work_item, :confidential, :group_level, :epic_with_legacy_epic, namespace: group, title: term)
      end

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        confidentiality_table_for_work_item_access
      end

      with_them do
        it_behaves_like 'search respects confidentiality'
      end
    end
  end
end
