# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Console::Menu, feature_category: :geo_replication do
  include EE::GeoHelpers

  # freeze: true prevents accidental mutation of shared test data
  let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }
  let(:output_stream) { StringIO.new }

  context 'with an instance of the abstract Menu class' do
    let(:action) { described_class.new(output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
    end

    it "raises an error when #prompt is not implemented" do
      expect { action.open }.to raise_error(NotImplementedError, "#{described_class} must implement #prompt")
    end
  end
end
