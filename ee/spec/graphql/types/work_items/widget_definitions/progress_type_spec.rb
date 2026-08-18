# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitions::ProgressType, feature_category: :team_planning do
  include GraphqlHelpers

  it 'exposes the expected fields' do
    expected_fields = %i[type show_popover]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  specify { expect(described_class.graphql_name).to eq('WorkItemWidgetDefinitionProgress') }

  describe '#show_popover' do
    before do
      stub_licensed_features(okrs: true)
    end

    let(:work_item_type) { build(:work_item_system_defined_type, :objective) }
    let(:widget_definition) do
      build(:work_item_system_defined_widget_definition, widget_type: 'progress', work_item_type_id: work_item_type.id)
    end

    let(:user) { create(:user) }

    subject(:result) { resolve_field(:show_popover, widget_definition, current_user: user) }

    context 'when widget_options is nil' do
      before do
        allow(widget_definition).to receive(:widget_options).and_return(nil)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when widget_options exists but progress options are not set' do
      before do
        allow(widget_definition).to receive(:widget_options).and_return({})
      end

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when show_popover is set to true' do
      # objective type has the show_popover widget option enabled by default

      it 'returns true' do
        expect(result).to be true
      end
    end

    context 'when show_popover is set to false' do
      before do
        allow(widget_definition).to receive(:widget_options).and_return(
          { show_popover: false }
        )
      end

      it 'returns false' do
        expect(result).to be false
      end
    end
  end
end
