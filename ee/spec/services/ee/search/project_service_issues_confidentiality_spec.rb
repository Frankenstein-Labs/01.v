# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, '#confidentiality', feature_category: :global_search do
  include SearchResultHelpers

  describe 'confidentiality', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'for ConfidentialityWorkItemsTable context'

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    context 'for issues' do
      let_it_be_with_reload(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, group: group) }
      let(:projects) { [project] }
      let(:search_level) { project }

      let_it_be(:term) { 'hello' }
      let_it_be(:non_confidential) { create :work_item, project: project, title: term }
      let_it_be(:confidential) { create(:work_item, :confidential, title: term, project: project) }
      let_it_be_with_reload(:confidential_user_as_assignee) do
        create(:work_item, :confidential, title: term, project: project)
      end

      let_it_be_with_reload(:confidential_user_as_author) do
        create(:work_item, :confidential, title: term, project: project)
      end

      let(:scope) { 'issues' }
      let(:search) { term }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        confidentiality_table_for_work_item_access
      end

      with_them do
        it_behaves_like 'search respects confidentiality'
      end
    end
  end
end
