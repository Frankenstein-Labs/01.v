# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::SystemDefined::Templates::Lifecycle, feature_category: :team_planning do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }

  subject(:template_lifecycle) do
    described_class.new(namespace: group, system_defined_lifecycle: system_defined_lifecycle)
  end

  describe '.in_namespace' do
    it 'returns template lifecycles for all system defined lifecycles' do
      templates = described_class.in_namespace(group)

      expect(templates).to all(be_a(described_class))
      expect(templates.size).to eq(WorkItems::Statuses::SystemDefined::Lifecycle.all.size)
      expect(templates.first).to have_attributes(
        namespace: group,
        system_defined_lifecycle: be_a(WorkItems::Statuses::SystemDefined::Lifecycle)
      )
    end
  end

  describe '#to_global_id' do
    it 'generates global id with name as identifier' do
      expect(template_lifecycle.to_global_id.to_s).to eq(
        'gid://gitlab/WorkItems::Statuses::SystemDefined::Templates::Lifecycle/Default'
      )
    end
  end

  describe '#name' do
    it 'delegates to system_defined_lifecycle' do
      expect(template_lifecycle.name).to eq(system_defined_lifecycle.name)
    end
  end

  describe '#work_item_types' do
    it 'returns an empty array' do
      expect(template_lifecycle.work_item_types).to eq([])
    end
  end

  describe '#statuses' do
    context 'when namespace has no custom statuses' do
      it 'returns template statuses with system defined attributes' do
        statuses = template_lifecycle.statuses

        expect(statuses).to all(be_a(WorkItems::Statuses::SystemDefined::Templates::Status))
        expect(statuses.size).to eq(system_defined_lifecycle.statuses.size)

        statuses.each do |status|
          system_defined_status = system_defined_lifecycle.statuses.find { |s| s.name == status.name }

          expect(status).to have_attributes(
            name: system_defined_status.name,
            color: system_defined_status.color,
            description: system_defined_status.description,
            category: system_defined_status.category.to_s
          )
        end
      end
    end

    context 'when namespace has custom statuses with matching names' do
      # Simple test setup, we don't need a custom lifecycle here because we only target custom statuses.
      # This is not a valid setup but reduces factory creations
      let_it_be(:custom_status) do
        create(:work_item_custom_status,
          namespace: group,
          name: 'To do',
          color: '#FF0000',
          description: 'Custom description',
          category: :to_do
        )
      end

      it 'returns template statuses with merged custom attributes' do
        statuses = template_lifecycle.statuses
        matching_status = statuses.find { |s| s.name == 'To do' }

        expect(matching_status).to have_attributes(
          name: 'To do',
          color: '#FF0000',
          description: 'Custom description',
          category: 'to_do'
        )
      end
    end

    context 'when namespace has custom statuses with non-matching names' do
      let_it_be(:custom_status) { create(:work_item_custom_status, :open, namespace: group) }

      it 'returns template statuses with system defined attributes only' do
        statuses = template_lifecycle.statuses

        statuses.each do |status|
          system_status = system_defined_lifecycle.statuses.find { |s| s.name == status.name }
          expect(status).to have_attributes(
            color: system_status.color,
            description: system_status.description
          )
        end
      end
    end
  end

  describe '#custom_statuses_by_name' do
    context 'when namespace has no custom statuses' do
      it 'returns empty hash' do
        expect(template_lifecycle.custom_statuses_by_name).to eq({})
      end
    end

    context 'when namespace has custom statuses' do
      let_it_be(:custom_status1) { create(:work_item_custom_status, namespace: group, name: 'Custom One') }
      let_it_be(:custom_status2) { create(:work_item_custom_status, namespace: group, name: 'Custom Two') }

      it 'returns hash indexed by name' do
        result = template_lifecycle.custom_statuses_by_name

        expect(result).to eq({
          'Custom One' => custom_status1,
          'Custom Two' => custom_status2
        })
      end
    end
  end

  describe '#default_open_status' do
    context 'when namespace has no custom statuses' do
      it 'returns template status with system defined attributes' do
        default_status = template_lifecycle.default_open_status

        expect(default_status).to be_a(WorkItems::Statuses::SystemDefined::Templates::Status)
        expect(default_status).to have_attributes(
          name: system_defined_lifecycle.default_open_status.name,
          color: system_defined_lifecycle.default_open_status.color
        )
      end
    end

    context 'when namespace has matching custom status' do
      let_it_be(:custom_status) do
        create(:work_item_custom_status,
          namespace: group,
          name: system_defined_lifecycle.default_open_status.name,
          color: '#000000',
          description: 'Custom open status'
        )
      end

      it 'returns template status with merged custom attributes' do
        default_status = template_lifecycle.default_open_status

        expect(default_status).to have_attributes(
          name: system_defined_lifecycle.default_open_status.name,
          color: '#000000',
          description: 'Custom open status'
        )
      end
    end
  end

  describe '#default_closed_status' do
    context 'when namespace has no custom statuses' do
      it 'returns template status with system defined attributes' do
        default_status = template_lifecycle.default_closed_status

        expect(default_status).to be_a(WorkItems::Statuses::SystemDefined::Templates::Status)
        expect(default_status).to have_attributes(
          name: system_defined_lifecycle.default_closed_status.name,
          color: system_defined_lifecycle.default_closed_status.color
        )
      end
    end

    context 'when namespace has matching custom status' do
      let_it_be(:custom_status) do
        create(:work_item_custom_status,
          :closed,
          namespace: group,
          name: system_defined_lifecycle.default_closed_status.name,
          color: '#000000',
          description: 'Custom closed status'
        )
      end

      it 'returns template status with merged custom attributes' do
        default_status = template_lifecycle.default_closed_status

        expect(default_status).to have_attributes(
          name: system_defined_lifecycle.default_closed_status.name,
          color: '#000000',
          description: 'Custom closed status'
        )
      end
    end
  end

  describe '#default_duplicate_status' do
    context 'when namespace has no custom statuses' do
      it 'returns template status with system defined attributes' do
        default_status = template_lifecycle.default_duplicate_status

        expect(default_status).to be_a(WorkItems::Statuses::SystemDefined::Templates::Status)
        expect(default_status).to have_attributes(
          name: system_defined_lifecycle.default_duplicate_status.name,
          color: system_defined_lifecycle.default_duplicate_status.color
        )
      end
    end

    context 'when namespace has matching custom status' do
      let_it_be(:custom_status) do
        create(:work_item_custom_status,
          :duplicate,
          namespace: group,
          name: system_defined_lifecycle.default_duplicate_status.name,
          color: '#000000',
          description: 'Custom duplicate status'
        )
      end

      it 'returns template status with merged custom attributes' do
        default_status = template_lifecycle.default_duplicate_status

        expect(default_status).to have_attributes(
          name: system_defined_lifecycle.default_duplicate_status.name,
          color: '#000000',
          description: 'Custom duplicate status'
        )
      end
    end
  end
end
