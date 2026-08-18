# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250224195802_remove_correct_work_item_type_id_from_work_item.rb')

RSpec.describe RemoveCorrectWorkItemTypeIdFromWorkItem, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250224195802
end
