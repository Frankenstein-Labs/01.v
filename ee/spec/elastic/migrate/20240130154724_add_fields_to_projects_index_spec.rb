# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240130154724_add_fields_to_projects_index.rb')

RSpec.describe AddFieldsToProjectsIndex, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240130154724
end
