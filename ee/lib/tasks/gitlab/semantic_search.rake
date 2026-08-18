# frozen_string_literal: true

namespace :gitlab do
  namespace :semantic_search do
    namespace :code do
      desc 'GitLab | Semantic Code Search | List information about Semantic Code Search integration'
      task :info, [:watch_interval] => :gitlab_environment do |t, args|
        Search::RakeTask::SemanticSearch.info(
          name: t.name,
          watch_interval: args[:watch_interval]
        )
      end
    end
  end
end
