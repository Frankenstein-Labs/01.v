# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  describe 'visibility', :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    let(:search_level) { group }
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be_with_reload(:shared_with_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :repository, namespace: group) }
    let(:projects) { [project] }
    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }
    let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }
    let(:scope) { 'blobs' }
    let(:search) { '.gitmodules' }

    context 'for blobs' do
      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access_and_non_private_project_only
      end

      with_them do
        context 'when using advanced search', :elastic_delete_by_query do
          before do
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

            project.repository.index_commits_and_blobs
          end

          it_behaves_like 'search respects visibility'
        end

        context 'when using zoekt', :zoekt_settings_enabled, :zoekt_cache_disabled do
          before do
            zoekt_ensure_namespace_indexed!(group)
          end

          it_behaves_like 'search respects visibility'
        end
      end

      describe 'custom roles' do
        context 'when using advanced search', :elastic_delete_by_query do
          before do
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
            project.repository.index_commits_and_blobs
          end

          it_behaves_like 'supports custom role access :read_code access'
        end

        context 'when using zoekt', :zoekt_settings_enabled, :zoekt_cache_disabled do
          before do
            zoekt_ensure_namespace_indexed!(group)
          end

          it_behaves_like 'supports custom role access :read_code access'
        end
      end
    end
  end
end
