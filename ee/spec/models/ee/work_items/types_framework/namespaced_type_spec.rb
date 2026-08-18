# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::NamespacedType, feature_category: :team_planning do
  describe '#class' do
    it 'returns the wrapped type class for custom types' do
      custom_type = build(:work_item_custom_type)
      namespaced = described_class.new(custom_type)

      expect(namespaced.class).to eq(WorkItems::TypesFramework::Custom::Type)
    end
  end

  describe '#enabled_by_default_for_new_namespaces?', :request_store do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

    subject(:namespaced_type) do
      described_class.new(issue_type, namespace: root_group)
    end

    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    context 'when no settings record exists' do
      it 'returns true' do
        expect(namespaced_type.enabled_by_default_for_new_namespaces?).to be true
      end
    end

    context 'when customizable_type_visibility is false' do
      before do
        create(:work_item_settings, namespace: root_group, customizable_type_visibility: false)
      end

      it 'returns true' do
        expect(namespaced_type.enabled_by_default_for_new_namespaces?).to be true
      end
    end

    context 'when customizable_type_visibility is true' do
      let_it_be(:settings) do
        create(:work_item_settings, namespace: root_group, customizable_type_visibility: true)
      end

      it 'returns true when no defaults row exists for this type' do
        expect(namespaced_type.enabled_by_default_for_new_namespaces?).to be true
      end

      it 'returns false when defaults row has enabled: false' do
        create(:work_item_type_visibility_default, namespace: root_group,
          work_item_type_id: issue_type.id, enabled: false)

        expect(namespaced_type.enabled_by_default_for_new_namespaces?).to be false
      end

      it 'returns true when defaults row has enabled: true' do
        create(:work_item_type_visibility_default, namespace: root_group,
          work_item_type_id: issue_type.id, enabled: true)

        expect(namespaced_type.enabled_by_default_for_new_namespaces?).to be true
      end
    end

    context 'when namespace is nil' do
      subject(:namespaced_type) do
        described_class.new(issue_type, namespace: nil)
      end

      it 'returns true' do
        expect(namespaced_type.enabled_by_default_for_new_namespaces?).to be true
      end
    end
  end
end
