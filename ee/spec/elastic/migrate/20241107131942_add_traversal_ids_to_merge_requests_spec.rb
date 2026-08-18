# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241107131942_add_traversal_ids_to_merge_requests.rb')

RSpec.describe AddTraversalIdsToMergeRequests, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241107131942
end
