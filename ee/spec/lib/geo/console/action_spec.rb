# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Console::Action, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }
  let(:output_stream) { StringIO.new }

  context 'with an instance of the abstract Action class' do
    let(:action) { described_class.new(output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
    end

    it "raises an error when #name is not implemented" do
      expect { action.open }.to raise_error(NotImplementedError, "#{described_class} must implement #name")
    end

    it "raises an error when #execute is not implemented" do
      allow(action).to receive(:name).and_return("Test Action")

      expect { action.open }.to raise_error(NotImplementedError, "#{described_class} must implement #execute")
    end
  end

  context 'with an instance that implements Action' do
    let(:action) { DummyGeoConsoleAction.new(output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
      stub_dummy_console_action
    end

    describe '#open' do
      context 'when an error occurs during #execute' do
        before do
          allow(action).to receive(:execute).and_raise(StandardError.new("Test error"))
        end

        it 'prints the error message and re-raises the error' do
          expect { action.open }.to raise_error("Test error")
          expect(output_stream.string).to include("Test error")
        end
      end

      context 'when debug logging is enabled in development' do
        before do
          allow(Rails.logger).to receive(:level).and_return(0)
          allow(action).to receive(:development?).and_return(true)
        end

        it 'temporarily sets the log level to :info' do
          expect(Rails.logger).to receive(:level=).with(:info)
          expect(Rails.logger).to receive(:level=).with(0)

          action.open
        end
      end
    end
  end
end
