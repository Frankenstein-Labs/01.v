# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::KnownError, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let(:error_type) { Geo::Errors::ErrorType.find_by(name: 'url_blocked') }

  subject(:known_error) { described_class.new(error_type) }

  describe '#detected? / #affected_count' do
    context 'when a failed registry matches the pattern' do
      before do
        create(:geo_package_file_registry, :failed, last_sync_failure: 'URL is blocked: Host cannot be resolved')
      end

      it 'counts the matching registry and detects the error', :aggregate_failures do
        expect(known_error.affected_count).to eq(1)
        expect(known_error.detected?).to be(true)
      end

      it 'labels an uncapped count as the exact number' do
        expect(known_error.affected_count_label).to eq('1')
      end

      it 'suffixes the label when the resolution capped its count' do
        allow(known_error.resolution).to receive(:count_capped?).and_return(true)

        expect(known_error.affected_count_label).to eq('1+')
      end
    end

    context 'when no failed registry matches the pattern' do
      before do
        create(:geo_package_file_registry, :failed, last_sync_failure: 'Some unrelated failure')
      end

      it 'counts zero and does not detect the error', :aggregate_failures do
        expect(known_error.affected_count).to eq(0)
        expect(known_error.detected?).to be(false)
      end
    end
  end

  describe '#runnable_on_current_site?' do
    it 'is true on the site the error resolves on (secondary)' do
      stub_secondary_node

      expect(known_error.runnable_on_current_site?).to be(true)
    end

    it 'is false on the other site' do
      stub_primary_node

      expect(known_error.runnable_on_current_site?).to be(false)
    end

    it 'is false when the catalog entry has an unrecognised site' do
      allow(error_type).to receive(:site).and_return('elsewhere')

      expect(known_error.runnable_on_current_site?).to be(false)
    end

    it 'is false when the catalog entry is not resolvable' do
      stub_secondary_node
      allow(error_type).to receive(:resolvable).and_return(false)

      expect(known_error.runnable_on_current_site?).to be(false)
    end
  end
end
