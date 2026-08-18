# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::SystemDefined::Templates::Status, feature_category: :team_planning do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }
  let_it_be(:system_defined_status) { system_defined_lifecycle.statuses.first }

  let(:lifecycle_template) do
    WorkItems::Statuses::SystemDefined::Templates::Lifecycle.new(
      namespace: group,
      system_defined_lifecycle: system_defined_lifecycle
    )
  end

  subject(:template_status) do
    described_class.new(
      lifecycle_template: lifecycle_template,
      system_defined_status: system_defined_status
    )
  end

  describe '#to_global_id' do
    it 'generates global id with name as identifier' do
      expect(template_status.to_global_id.to_s).to eq(
        'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Status/To+do'
      )
    end
  end

  describe '#namespace' do
    it 'delegates to lifecycle_template' do
      expect(template_status.namespace).to eq(group)
    end
  end

  describe '#name' do
    it 'returns system_defined_status name' do
      expect(template_status.name).to eq(system_defined_status.name)
    end
  end

  describe 'attribute merging behavior' do
    context 'when namespace has no custom statuses' do
      it 'returns system defined attributes' do
        expect(template_status).to have_attributes(
          name: system_defined_status.name,
          color: system_defined_status.color,
          description: system_defined_status.description,
          category: system_defined_status.category.to_s,
          icon_name: system_defined_status.icon_name
        )
      end
    end

    context 'when namespace has custom status with matching name' do
      let!(:custom_status) do
        create(:work_item_custom_status,
          namespace: group,
          name: system_defined_status.name,
          color: '#000000',
          description: 'Custom description',
          category: system_defined_status.category
        )
      end

      it 'returns merged attributes with custom overrides' do
        expect(template_status).to have_attributes(
          name: system_defined_status.name,
          color: '#000000',
          description: 'Custom description',
          category: system_defined_status.category.to_s,
          icon_name: system_defined_status.icon_name
        )
      end
    end

    context 'when namespace has custom status with non-matching name' do
      let!(:custom_status) do
        create(:work_item_custom_status,
          namespace: group,
          name: 'Different Name',
          color: '#000000',
          description: 'Custom description'
        )
      end

      it 'returns system defined attributes only' do
        expect(template_status).to have_attributes(
          name: system_defined_status.name,
          color: system_defined_status.color,
          description: system_defined_status.description,
          category: system_defined_status.category.to_s,
          icon_name: system_defined_status.icon_name
        )
      end
    end

    context 'when custom status description is nil' do
      let!(:custom_status) do
        create(:work_item_custom_status,
          namespace: group,
          name: system_defined_status.name,
          color: '#000000',
          description: nil,
          category: system_defined_status.category
        )
      end

      it 'respects nil custom description without falling back' do
        expect(template_status).to have_attributes(
          name: system_defined_status.name,
          color: '#000000',
          description: nil,
          category: system_defined_status.category.to_s,
          icon_name: system_defined_status.icon_name
        )
      end
    end
  end
end
