# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Console::MultipleChoiceMenu, feature_category: :geo_replication do
  include EE::GeoHelpers

  # freeze: true prevents accidental mutation of shared test data
  let_it_be(:primary_node, freeze: true) { create(:geo_node, primary: true, name: "New York") }
  let(:output_stream) { StringIO.new }

  context 'with an instance of the abstract MultipleChoiceMenu class' do
    let(:action) { described_class.new(output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
    end

    it "raises an error when #choices is not implemented" do
      expect { action.open }.to raise_error(NotImplementedError, "#{described_class} must implement #choices")
    end
  end

  context 'with an instance that implements MultipleChoiceMenu' do
    let(:action) { DummyGeoConsoleMultipleChoiceMenu.new(input_stream: input_stream, output_stream: output_stream) }

    before do
      stub_current_geo_node(primary_node)
      stub_dummy_console_multiple_choice_menu
    end

    describe '#open' do
      context "when the user enters a number which is not a valid choice" do
        let(:input_stream) { StringIO.new("3\n") }

        it "validates that the 1-based choice number exists" do
          allow(action).to receive(:open_choice) # do not continue prompting

          action.open

          expect(output_stream.string).to include("You entered: 3\nChoice not found. Please try again.")
        end
      end

      context "when the user enters a number which is a valid choice" do
        let(:input_stream) { StringIO.new("1\n") }

        it "opens the selected choice" do
          action.open
        end
      end
    end
  end
end
