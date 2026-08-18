# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250708194823_remove_notes_fields_from_work_items.rb')

RSpec.describe RemoveNotesFieldsFromWorkItems, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250708194823
end
