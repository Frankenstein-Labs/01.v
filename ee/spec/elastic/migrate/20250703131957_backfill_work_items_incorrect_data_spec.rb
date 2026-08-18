# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20250703131957_backfill_work_items_incorrect_data.rb')

# See https://docs.gitlab.com/ee/development/testing_guide/best_practices.html#elasticsearch-specs
# for more information on how to write search migration specs for GitLab.
RSpec.describe BackfillWorkItemsIncorrectData, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250703131957
end
