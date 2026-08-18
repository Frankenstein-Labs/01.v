# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260216152309_add_traversal_ids_to_commits.rb')

RSpec.describe AddTraversalIdsToCommits, :elastic, feature_category: :global_search do
  let(:version) { 20260216152309 }

  include_examples 'migration adds mapping'
end
