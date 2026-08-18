# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241003151804_add_notes_to_work_items.rb')

RSpec.describe AddNotesToWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241003151804
end
