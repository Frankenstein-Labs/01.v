# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SystemCheck::CurrentNodeCheck, :geo, :silence_stdout, feature_category: :geo_replication do
  subject(:current_node_check) { described_class.new }

  describe '#check?' do
    context 'when the current machine has a matching GeoNode' do
      it 'returns true' do
        create(:geo_node, :primary, name: GeoNode.current_node_name)

        expect(current_node_check.check?).to be_truthy
      end
    end

    context 'when the current machine does not have a matching GeoNode' do
      it 'returns false' do
        expect(GeoNode).to receive(:current_node_name).twice.and_return('Foo')

        expect(current_node_check.check?).to be_falsey
      end
    end
  end

  describe '.check_pass' do
    it 'outputs additional helpful info' do
      # Clear any cached Geo state to ensure clean test environment
      Gitlab::Geo.expire_cache!

      allow(GeoNode).to receive(:current_node_name).and_return('Foo')

      primary_node = create(:geo_node, :primary, name: GeoNode.current_node_name)

      # Ensure Gitlab::Geo.current_node returns our created node
      allow(Gitlab::Geo).to receive(:current_node).and_return(primary_node)

      expect(described_class.check_pass).to eq('yes, found a primary node named "Foo"')
    end
  end
end
