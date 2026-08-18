# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240213091440_reindex_projects_to_apply_routing.rb')

RSpec.describe ReindexProjectsToApplyRouting, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240213091440
end
