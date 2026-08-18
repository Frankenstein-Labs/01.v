# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Lifecycles::Provider, feature_category: :team_planning do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:other_namespace) { create(:group) }
  let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

  let(:system_defined_lifecycle) { issue_type.system_defined_lifecycle }

  before do
    stub_licensed_features(work_item_status: true)
  end

  subject(:provider) { described_class.new(namespace.id) }

  describe '#find_by_type' do
    context 'when a custom lifecycle is attached to the type in the namespace' do
      let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

      before do
        create(:work_item_type_custom_lifecycle,
          work_item_type: issue_type,
          namespace: namespace,
          lifecycle: custom_lifecycle)
      end

      it 'returns the custom lifecycle' do
        expect(provider.find_by_type(issue_type)).to eq(custom_lifecycle)
      end

      it 'returns the system-defined lifecycle for a type without a custom row' do
        expect(provider.find_by_type(task_type)).to eq(task_type.system_defined_lifecycle)
      end
    end

    context 'when no custom lifecycle is attached to the type in the namespace' do
      it 'returns the system-defined lifecycle' do
        expect(provider.find_by_type(issue_type)).to eq(system_defined_lifecycle)
      end
    end

    context 'when a custom lifecycle exists only in a different namespace' do
      let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_namespace) }

      before do
        create(:work_item_type_custom_lifecycle,
          work_item_type: issue_type,
          namespace: other_namespace,
          lifecycle: custom_lifecycle)
      end

      it 'returns the system-defined lifecycle' do
        expect(provider.find_by_type(issue_type)).to eq(system_defined_lifecycle)
      end
    end

    context 'when the namespace is nil' do
      subject(:provider) { described_class.new(nil) }

      it 'returns the system-defined lifecycle and does not raise' do
        expect(provider.find_by_type(issue_type)).to eq(system_defined_lifecycle)
      end
    end

    context 'when the type is a custom type converted from a system-defined type' do
      let_it_be(:converted_type) do
        create(:work_item_custom_type, :converted_from_issue, namespace: namespace)
      end

      let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

      before do
        create(:work_item_type_custom_lifecycle,
          work_item_type_id: converted_type.persistable_id,
          namespace: namespace,
          lifecycle: custom_lifecycle)
      end

      it 'resolves the converted custom type to the custom lifecycle' do
        expect(provider.find_by_type(converted_type)).to eq(custom_lifecycle)
      end

      it 'resolves the system-defined origin type to the same lifecycle' do
        expect(provider.find_by_type(issue_type)).to eq(custom_lifecycle)
      end
    end
  end

  describe '#find_custom_by_type' do
    context 'when a custom lifecycle is attached to the type in the namespace' do
      let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

      before do
        create(:work_item_type_custom_lifecycle,
          work_item_type: issue_type,
          namespace: namespace,
          lifecycle: custom_lifecycle)
      end

      it 'returns the custom lifecycle' do
        expect(provider.find_custom_by_type(issue_type)).to eq(custom_lifecycle)
      end

      it 'returns nil for a type without a custom row' do
        expect(provider.find_custom_by_type(task_type)).to be_nil
      end
    end

    context 'when no custom lifecycle is attached to the type in the namespace' do
      it 'returns nil' do
        expect(provider.find_custom_by_type(issue_type)).to be_nil
      end
    end

    context 'when the namespace is nil' do
      subject(:provider) { described_class.new(nil) }

      it 'returns nil and does not raise' do
        expect(provider.find_custom_by_type(issue_type)).to be_nil
      end
    end
  end

  describe 'index caching' do
    let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

    before do
      create(:work_item_type_custom_lifecycle,
        work_item_type: issue_type,
        namespace: namespace,
        lifecycle: custom_lifecycle)
    end

    it 'does not issue more queries when more types are indexed', :request_store do
      control = ActiveRecord::QueryRecorder.new do
        described_class.new(namespace.id).find_custom_by_type(issue_type)
      end

      task_lifecycle = create(:work_item_custom_lifecycle, namespace: namespace)
      create(:work_item_type_custom_lifecycle,
        work_item_type: task_type,
        namespace: namespace,
        lifecycle: task_lifecycle)

      expect do
        described_class.new(namespace.id).find_custom_by_type(issue_type)
      end.not_to exceed_query_limit(control)
    end

    it 'builds the index once per namespace per request', :request_store do
      provider.find_custom_by_type(issue_type)

      control = ActiveRecord::QueryRecorder.new do
        provider.find_custom_by_type(issue_type)
        provider.find_custom_by_type(task_type)
        described_class.new(namespace.id).find_custom_by_type(issue_type)
      end

      expect(control.count).to eq(0)
    end
  end
end
