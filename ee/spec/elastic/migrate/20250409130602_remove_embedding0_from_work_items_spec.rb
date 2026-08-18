# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250409130602_remove_embedding0_from_work_items.rb')

RSpec.describe RemoveEmbedding0FromWorkItems, :elastic_delete_by_query, :sidekiq_inline, feature_category: :global_search do
  let(:version) { 20250409130602 }

  it_behaves_like 'a deprecated Advanced Search migration', 20250409130602
end
