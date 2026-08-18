# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  describe 'visibility', :elastic_delete_by_query, :sidekiq_inline do
    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    context 'for wikis' do
      let_it_be(:committer) { create(:user) }
      let_it_be_with_reload(:group) { create(:group, :wiki_enabled) }
      let_it_be_with_reload(:shared_with_group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, :wiki_repo, namespace: group) }
      let(:projects) { [project] }

      let(:search_level) { project }
      let(:user) { create_user_from_membership(project, membership) }
      let(:user_in_group) { create_user_from_membership(group, membership) }
      let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }

      let(:scope) { 'wiki_blobs' }
      let(:search) { 'project-term' }

      before_all do
        Wiki.for_container(project, committer).create_page('test.md', "# project-term", :markdown, 'commit message')
      end

      context 'for project wikis' do
        include_context 'ProjectPolicyTable context'

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

      it 'adds correct routing field in the elasticsearch request' do
        project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
        project.wiki.index_wiki_blobs
        ensure_elasticsearch_index!

        described_class.new(nil, project, search: 'test').execute.objects(scope)

        assert_routing_field("n_#{project.root_ancestor.id}")
      end
    end
  end
end
