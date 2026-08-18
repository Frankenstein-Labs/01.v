# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20241105111645_add_work_item_type_correct_id.rb')

RSpec.describe AddWorkItemTypeCorrectId, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20241105111645
end
