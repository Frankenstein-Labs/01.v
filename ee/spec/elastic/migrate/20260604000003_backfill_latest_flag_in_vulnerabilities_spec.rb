# frozen_string_literal: true

require 'spec_helper'
require File.expand_path('ee/elastic/migrate/20260604000003_backfill_latest_flag_in_vulnerabilities.rb')

RSpec.describe BackfillLatestFlagInVulnerabilities,
  feature_category: :global_search do
  let(:version) { 20260604000003 }

  describe 'migration', :elastic_delete_by_query, :sidekiq_inline do
    include_examples 'migration reindex based on schema_version' do
      let(:expected_throttle_delay) { 15.seconds }
      let(:expected_batch_size) { 10_000 }

      let(:objects) do
        create_list(:vulnerability_read, 3).each do |read|
          allow(read).to receive(:dual_write_to_es?).and_return(false)
        end
      end
    end
  end
end
