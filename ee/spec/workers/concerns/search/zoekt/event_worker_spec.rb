# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::EventWorker, feature_category: :global_search do
  describe 'deduplication strategy' do
    let(:event_worker_classes) do
      # Find all concrete classes that include Search::Zoekt::EventWorker
      Search::Zoekt.constants
        .map { |const| Search::Zoekt.const_get(const, false) }
        .select { |const| const.is_a?(Class) && const.included_modules.include?(described_class) }
    end

    it 'ensures all event workers have correct deduplicate strategy', :aggregate_failures do
      event_worker_classes.each do |worker_class|
        expect(worker_class.get_deduplicate_strategy).to eq(:until_executed),
          "Expected #{worker_class.name} to have :until_executed deduplicate strategy"

        expect(worker_class.get_deduplication_options).to include({ if_deduplicated: :reschedule_once }),
          "Expected #{worker_class.name} to have :reschedule_once deduplication option"
      end
    end
  end
end
