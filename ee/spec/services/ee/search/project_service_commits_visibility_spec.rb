# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ProjectService, '#visibility', feature_category: :global_search do
  include SearchResultHelpers
  include ProjectHelpers
  include UserHelpers

  describe 'visibility', :sidekiq_inline, :elastic_delete_by_query do
    using RSpec::Parameterized::TableSyntax
    include_context 'ProjectPolicyTable context'

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:shared_with_group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :repository, :in_group, namespace: group) }

    let(:user) { create_user_from_membership(project, membership) }
    let(:user_in_group) { create_user_from_membership(group, membership) }
    let(:user_in_shared_group) { create_user_from_membership(shared_with_group, membership) }

    let(:projects) { [project] }
    let(:search_level) { project }

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
      project.repository.index_commits_and_blobs
    end

    where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
      permission_table_for_guest_feature_access_and_non_private_project_only
    end

    with_them do
      context 'for commits' do
        it_behaves_like 'search respects visibility' do
          let(:scope) { 'commits' }
          let(:search) { 'initial' }
        end
      end
    end
  end
end
