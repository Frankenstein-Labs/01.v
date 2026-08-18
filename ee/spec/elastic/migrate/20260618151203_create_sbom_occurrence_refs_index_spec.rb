# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260618151203_create_sbom_occurrence_refs_index.rb')

RSpec.describe CreateSbomOccurrenceRefsIndex, feature_category: :dependency_management do
  it_behaves_like 'migration creates a new index', 20260618151203, ::Sbom::OccurrenceRef
end
