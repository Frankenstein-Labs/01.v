# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240704125425_add_label_ids_to_merge_request.rb')

RSpec.describe AddLabelIdsToMergeRequest, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240704125425
end
