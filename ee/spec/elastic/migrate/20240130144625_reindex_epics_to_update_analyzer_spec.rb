# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20240130144625_reindex_epics_to_update_analyzer.rb')

RSpec.describe ReindexEpicsToUpdateAnalyzer, feature_category: :global_search do
  it_behaves_like 'a deprecated Advanced Search migration', 20240130144625
end
