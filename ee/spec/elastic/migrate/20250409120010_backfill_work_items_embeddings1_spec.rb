# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250409120010_backfill_work_items_embeddings1.rb')

RSpec.describe BackfillWorkItemsEmbeddings1, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250409120010
end
