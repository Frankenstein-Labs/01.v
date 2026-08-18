# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitionInterface, feature_category: :team_planning do
  describe '.resolve_type' do
    using RSpec::Parameterized::TableSyntax

    where(:widget_type, :widget_definition_type_class) do
      'labels'        | Types::WorkItems::WidgetDefinitions::LabelsType
      'custom_fields' | Types::WorkItems::WidgetDefinitions::CustomFieldsType
      'status'        | Types::WorkItems::WidgetDefinitions::StatusType
    end

    subject { described_class.resolve_type(object, {}) }

    let(:object) do
      build(:work_item_system_defined_widget_definition, widget_type: widget_type)
    end

    with_them do
      it { is_expected.to eq(widget_definition_type_class) }
    end
  end
end
