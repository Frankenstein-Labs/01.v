# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::WorkItems::Features::CustomFields, feature_category: :team_planning do
  it_behaves_like 'work item widget entity parity',
    described_class,
    Types::WorkItems::Widgets::CustomFieldsType,
    exceptions: %w[widget_definition]

  describe described_class::CustomField do
    it_behaves_like 'work item widget entity parity',
      described_class,
      Types::Issuables::CustomFieldType
  end

  describe described_class::SelectOption do
    it_behaves_like 'work item widget entity parity',
      described_class,
      Types::Issuables::CustomFieldSelectOptionType
  end

  describe '#as_json' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:text_field) { build_stubbed(:custom_field, field_type: 'text', name: 'Text field') }
    let(:number_field) { build_stubbed(:custom_field, field_type: 'number', name: 'Number field') }
    let(:select_field) { build_stubbed(:custom_field, field_type: 'single_select', name: 'Select field') }
    let(:select_option) { build_stubbed(:custom_field_select_option, custom_field: select_field, value: 'High') }

    let(:custom_field_values) do
      [
        { custom_field: text_field, value: 'some text' },
        { custom_field: number_field, value: BigDecimal(10) },
        { custom_field: select_field, value: [select_option] }
      ]
    end

    let(:widget) { instance_double(WorkItems::Widgets::CustomFields, custom_field_values: custom_field_values) }

    subject(:representation) { described_class.new(widget).as_json }

    before do
      allow(select_field).to receive(:select_options).and_return([select_option])
      [text_field, number_field, select_field].each do |field|
        allow(field).to receive(:work_item_types).and_return([issue_type])
      end
    end

    it 'exposes each value with its custom field metadata', :aggregate_failures do
      values = representation[:custom_field_values]

      expect(values.pluck(:custom_field).pluck(:name))
        .to eq(['Text field', 'Number field', 'Select field'])
      expect(values.first[:custom_field]).to include(
        id: text_field.id,
        field_type: 'text',
        active: true,
        work_item_types: [a_hash_including(id: issue_type.id, name: 'Issue')]
      )
    end

    it 'exposes text values as strings' do
      expect(representation[:custom_field_values].first).to include(value: 'some text')
    end

    it 'exposes number values as floats to match the GraphQL API', :aggregate_failures do
      number_value = representation[:custom_field_values].find { |v| v[:custom_field][:field_type] == 'number' }

      expect(number_value[:value]).to eq(10.0)
      expect(number_value[:value]).to be_a(Float)
    end

    it 'exposes selected options for select fields instead of a scalar value', :aggregate_failures do
      select_value = representation[:custom_field_values].find { |v| v[:custom_field][:field_type] == 'single_select' }

      expect(select_value).not_to have_key(:value)
      expect(select_value[:selected_options]).to contain_exactly(
        a_hash_including(id: select_option.id, value: 'High')
      )
      expect(select_value[:custom_field]).to include(select_options: [a_hash_including(value: 'High')])
    end
  end
end
