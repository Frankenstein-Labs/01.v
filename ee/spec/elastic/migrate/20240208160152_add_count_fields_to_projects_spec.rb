# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240208160152_add_count_fields_to_projects.rb')

RSpec.describe AddCountFieldsToProjects, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240208160152
end
