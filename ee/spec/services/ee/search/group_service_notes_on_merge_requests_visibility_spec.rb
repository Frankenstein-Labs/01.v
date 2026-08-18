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

    context 'for notes' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on merge requests' do
        let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
        let_it_be(:merge_request2) { create(:merge_request, target_project: project2, source_project: project2) }
        let_it_be(:note) { create :note, noteable: merge_request, project: project }
        let_it_be(:note2) { create :note, noteable: merge_request2, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_reporter_feature_access
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end
    end
  end
end
