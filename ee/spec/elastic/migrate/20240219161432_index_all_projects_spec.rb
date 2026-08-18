# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240219161432_index_all_projects.rb')

RSpec.describe IndexAllProjects, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240219161432
end
