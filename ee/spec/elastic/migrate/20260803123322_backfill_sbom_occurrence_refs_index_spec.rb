# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260803123322_backfill_sbom_occurrence_refs_index.rb')

RSpec.describe BackfillSbomOccurrenceRefsIndex, :elastic, feature_category: :dependency_management do
  let(:version) { 20260803123322 }

  include_examples 'migration reindexes all data' do
    let(:objects) { create_list(:sbom_occurrence_ref, 3) }
    let(:factory_to_create_objects) { :sbom_occurrence_ref }
    let(:expected_throttle_delay) { 15.seconds }
    let(:expected_batch_size) { 10_000 }
  end
end
