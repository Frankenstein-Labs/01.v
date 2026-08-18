# frozen_string_literal: true

require 'spec_helper'
require File.expand_path(
  'ee/elastic/migrate/20250505125045_remove_correct_work_item_type_id_from_work_item_second_attempt.rb'
)

RSpec.describe RemoveCorrectWorkItemTypeIdFromWorkItemSecondAttempt, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20250505125045
end
