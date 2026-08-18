# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::GeoNodesCheck, :geo, :silence_stdout, feature_category: :geo_replication do
  subject(:check) { described_class.new }

  describe '#check?' do
    context 'when geo_nodes table exists' do
      it 'returns true' do
        expect(GeoNode.connection).to receive(:table_exists?).with(:geo_nodes).and_return(true)

        expect(check.check?).to be_truthy
      end
    end

    context 'when geo_nodes table does not exist' do
      it 'returns false' do
        expect(GeoNode.connection).to receive(:table_exists?).with(:geo_nodes).and_return(false)

        expect(check.check?).to be_falsey
      end
    end
  end

  describe '#show_error' do
    it 'displays helpful error messages' do
      expect(check).to receive(:try_fixing_it).with(
        'GeoNode table does not exist - please follow Geo docs to set up this node'
      )
      expect(check).to receive(:for_more_information).with('doc/administration/geo/index.md')

      check.show_error
    end
  end
end
