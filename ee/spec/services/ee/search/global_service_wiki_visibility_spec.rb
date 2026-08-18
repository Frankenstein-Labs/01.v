# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GlobalService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be(:committer) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :wiki_enabled) }
    let_it_be_with_reload(:shared_with_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :wiki_repo, namespace: group) }

    let(:projects) { [project] }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }
    let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }

    context 'for wikis' do
      let(:scope) { 'wiki_blobs' }

      context 'for project wikis' do
        include_context 'ProjectPolicyTable context'

        let(:search) { 'project-term' }

        before_all do
          Wiki.for_container(project, committer).create_page('test.md', "# project-term", :markdown, 'commit message')
        end

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          before do
            project.wiki.index_wiki_blobs
            ensure_elasticsearch_index!
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'for group wikis' do
        include_context 'for GroupPolicyTable context'

        let(:search) { 'group-term' }

        before_all do
          Wiki.for_container(group, committer).create_page('test.md', "# group-term", :markdown, 'commit message')
        end

        where(:project_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_group_wiki_access
        end

        with_them do
          before do
            # project associated with group must have visibility_level updated to allow
            # the shared example to update the group visibility_level setting. projects cannot
            # have higher visibility than the group to which they belong
            project.update!(visibility_level: Gitlab::VisibilityLevel.level_value(project_level.to_s))
            group.wiki.index_wiki_blobs

            ensure_elasticsearch_index!
          end

          # project access does not grant group wiki visibility
          # see https://docs.gitlab.com/user/project/wiki/group/#configure-group-wiki-visibility
          it_behaves_like 'search respects visibility', project_access: false, project_access_shared_group: false
        end
      end
    end
  end
end
