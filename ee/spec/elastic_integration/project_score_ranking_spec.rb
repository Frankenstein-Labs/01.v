# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project score ranking', :elastic_clean, :sidekiq_inline,
  :elasticsearch_settings_enabled, feature_category: :global_search do
  let_it_be(:admin) { create(:admin) }

  let(:options) { { current_user: admin, search_level: :global, project_ids: :any } }

  def search_ids(query)
    Project.elastic_search(query, options: options).records.map(&:id)
  end

  describe 'star count boost', :enable_admin_mode do
    it 'ranks a 0-star exact name match above a high-star weak match' do
      exact_match = create(:project, :public, name: 'unicorn-project', star_count: 0)
      create(:project, :public, name: 'some-other-project', star_count: 500)

      ensure_elasticsearch_index!

      results = search_ids('unicorn-project')
      expect(results.first).to eq(exact_match.id)
    end

    it 'ranks a high-star project above a 0-star project with equally weak matches' do
      create(:project, :public, name: 'alpha-widget', star_count: 0)
      high_star = create(:project, :public, name: 'beta-widget', star_count: 200)

      ensure_elasticsearch_index!

      results = search_ids('widget')
      expect(results.first).to eq(high_star.id)
    end
  end

  describe 'fork demotion', :enable_admin_mode do
    it 'ranks a non-fork above a fork with the same name and 0 stars' do
      original = create(:project, :public, name: 'rails-fork-test', star_count: 0)
      fork = create(:project, :public, name: 'rails-fork-test', star_count: 0)
      fork_network = create(:fork_network, root_project: original)
      create(:fork_network_member, project: fork, fork_network: fork_network,
        forked_from_project: original)

      ensure_elasticsearch_index!

      results = search_ids('rails-fork-test')
      expect(results.first).to eq(original.id)
    end
  end
end
