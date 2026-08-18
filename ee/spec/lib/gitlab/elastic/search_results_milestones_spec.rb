# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'milestones', feature_category: :global_search do
  let_it_be(:user) { create(:user) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'milestones', :elastic_delete_by_query do
    let(:scope) { 'milestones' }

    describe 'filtering' do
      let_it_be(:unarchived_project) { create(:project, :public) }
      let_it_be(:archived_project) { create(:project, :public, :archived) }
      let_it_be(:unarchived_result) { create(:milestone, project: unarchived_project, title: 'foo unarchived') }
      let_it_be(:archived_result) { create(:milestone, project: archived_project, title: 'foo archived') }
      let(:project_ids) { [unarchived_project.id, archived_project.id] }
      let(:results) { described_class.new(user, 'foo', filters: filters) }

      before do
        Elastic::ProcessInitialBookkeepingService.backfill_projects!(archived_project, unarchived_project)

        ensure_elasticsearch_index!
      end

      include_examples 'search results filtered by archived', nil, nil
    end
  end
end
