# frozen_string_literal: true

FactoryBot.define do
  factory :index_status do
    project { association(:project, :repository) }
    indexed_at { Time.now }
    last_commit { project.commit&.sha || Gitlab::Git::SHA1_EMPTY_TREE_ID }
    last_wiki_commit { project.wiki.repository.commit&.sha || Gitlab::Git::SHA1_BLANK_SHA }
  end
end
