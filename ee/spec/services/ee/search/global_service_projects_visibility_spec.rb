# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GlobalService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query do
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:group) { create(:group, :wiki_enabled) }
    let_it_be_with_reload(:shared_with_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, namespace: group) }

    let(:scope) { 'projects' }
    let(:search) { project.name }

    let(:projects) { [project] }
    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }
    let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }

    context 'for projects' do
      where(:project_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        before do
          project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))

          ensure_elasticsearch_index!
        end

        it_behaves_like 'search respects visibility', project_feature_setup: false
      end
    end
  end
end
