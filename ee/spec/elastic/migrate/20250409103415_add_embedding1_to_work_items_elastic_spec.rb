# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250409103415_add_embedding1_to_work_items_elastic.rb')

RSpec.describe AddEmbedding1ToWorkItemsElastic, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250409103415
end
