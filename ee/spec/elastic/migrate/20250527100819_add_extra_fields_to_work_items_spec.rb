# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250527100819_add_extra_fields_to_work_items.rb')

RSpec.describe AddExtraFieldsToWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250527100819
end
