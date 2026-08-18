# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241025160103_backfill_work_items_embeddings.rb')

RSpec.describe BackfillWorkItemsEmbeddings, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241025160103
end
