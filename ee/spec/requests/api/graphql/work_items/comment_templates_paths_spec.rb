# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'comment_templates_paths field', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:work_item) { create(:work_item, project: project) }

  let(:query) do
    graphql_query_for(
      'workItem',
      { 'id' => global_id_of(work_item) },
      <<~QUERY
      commentTemplatesPaths {
        href
        text
      }
      QUERY
    )
  end

  subject(:templates_path_data) { graphql_data.dig('workItem', 'commentTemplatesPaths') }

  before_all do
    project.add_maintainer(user)
    group.add_owner(user)
  end

  before do
    allow_next_instance_of(IssuablesHelper) do |instance|
      allow(instance).to receive(:current_user).and_return(user)
    end
  end

  describe 'with project comment templates permission' do
    before do
      allow_next_instance_of(::Types::WorkItemType) do |instance|
        allow(instance).to receive(:can?).with(user, :create_saved_replies, project).and_return(true)
        allow(instance).to receive(:can?).with(user, :create_saved_replies, group).and_return(false)
      end
    end

    it 'includes project comment templates in the response' do
      post_graphql(query, current_user: user)

      expect(templates_path_data.size).to eq(2)
      expect(templates_path_data).to include(
        a_hash_including(
          'text' => 'Project comment templates',
          'href' => ::Gitlab::Routing.url_helpers.project_comment_templates_path(project)
        )
      )
    end
  end

  describe 'with group comment templates permission' do
    before do
      allow_next_instance_of(::Types::WorkItemType) do |instance|
        allow(instance).to receive(:can?).with(user, :create_saved_replies, project).and_return(false)
        allow(instance).to receive(:can?).with(user, :create_saved_replies, group).and_return(true)
      end
    end

    it 'includes group comment templates in the response' do
      post_graphql(query, current_user: user)

      expect(templates_path_data).to include(
        a_hash_including(
          'text' => 'Group comment templates',
          'href' => ::Gitlab::Routing.url_helpers.group_comment_templates_path(group)
        )
      )
    end
  end
end
