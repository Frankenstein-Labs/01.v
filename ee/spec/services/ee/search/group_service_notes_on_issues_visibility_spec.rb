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

      context 'on issues' do
        let_it_be_with_reload(:issue) { create(:issue, project: project) }
        let_it_be_with_reload(:issue2) { create(:issue, project: project2) }
        let_it_be_with_reload(:note) { create :note, noteable: issue, project: project }
        let_it_be_with_reload(:note2) { create :note, noteable: issue2, project: project2, note: note.note }
        let_it_be_with_reload(:confidential_note) do
          note_author_and_assignee = project.creator
          issue2 = create(:issue, project: project, assignees: [note_author_and_assignee])
          create(:note, note: note.note, confidential: true,
            project: project, noteable: issue2, author: note_author_and_assignee)
        end

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_notes_feature_access
        end

        with_them do
          before do
            Elastic::ProcessInitialBookkeepingService.track!(note, note2, confidential_note)
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end
    end
  end
end
