# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20231016162120_reindex_epics_to_fix_label_ids.rb')

RSpec.describe ReindexEpicsToFixLabelIds, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20231016162120
end
