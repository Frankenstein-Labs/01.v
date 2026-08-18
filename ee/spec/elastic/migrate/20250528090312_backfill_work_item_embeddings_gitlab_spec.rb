# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250528090312_backfill_work_item_embeddings_gitlab.rb')

RSpec.describe BackfillWorkItemEmbeddingsGitlab, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250528090312
end
