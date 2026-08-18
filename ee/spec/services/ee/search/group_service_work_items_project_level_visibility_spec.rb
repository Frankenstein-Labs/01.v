# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'work_items scope visibility for project-level work items', :elastic_delete_by_query, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be(:shared_with_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be_with_reload(:project2) { create(:project) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }
    let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }

    let(:projects) { [project, project2] }
    let(:search_level) { group }

    let_it_be(:work_item) { create(:work_item, project: project) }
    let_it_be(:work_item2) { create(:work_item, project: project2, title: work_item.title) }

    let(:scope) { 'work_items' }
    let(:search) { work_item.title }

    where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
      permission_table_for_guest_feature_access
    end

    with_them do
      before do
        Elastic::ProcessInitialBookkeepingService.track!(work_item, work_item2)
        ensure_elasticsearch_index!
      end

      it_behaves_like 'search respects visibility'
    end
  end

  def params
    { search: search, scope: scope }
  end
end
