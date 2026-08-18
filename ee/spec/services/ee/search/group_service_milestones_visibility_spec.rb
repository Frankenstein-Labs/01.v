# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:shared_with_group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group) }
    let_it_be_with_refind(:project2) { create(:project) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }
    let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }

    let(:projects) { [project, project2] }
    let(:search_level) { group }

    context 'for milestones' do
      let(:scope) { 'milestones' }
      let(:search) { milestone.title }
      let_it_be_with_reload(:milestone) { create :milestone, project: project }

      where(:project_level, :issues_access_level, :merge_requests_access_level, :membership, :admin_mode,
        :expected_count) do
        permission_table_for_milestone_access
      end

      with_them do
        before do
          project.update!(
            visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s),
            issues_access_level: issues_access_level,
            merge_requests_access_level: merge_requests_access_level
          )

          Elastic::ProcessInitialBookkeepingService.track!(milestone)

          ensure_elasticsearch_index!
        end

        # milestones cannot use the project feature setup helper in the shared example
        # because they need to update multiple access levels.
        it_behaves_like 'search respects visibility', project_feature_setup: false
      end
    end
  end
end
