# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::CascadeBuiltInProjectTemplatesEnabledWorker, feature_category: :source_code_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:child_group_1) { create(:group, parent: group) }
  let_it_be_with_reload(:child_group_2) { create(:group, parent: group) }
  let_it_be_with_reload(:descendant_group) { create(:group, parent: child_group_1) }
  let_it_be_with_reload(:unrelated_group) { create(:group) }

  let(:group_id) { group.id }

  let(:worker) { described_class.new }
  let(:built_in_project_templates_enabled) { true }
  let(:limiter) { instance_double(Gitlab::Metrics::RuntimeLimiter, over_time?: false, was_over_time?: false) }
  let(:cascaded_groups) { [group, child_group_1, child_group_2, descendant_group] }

  before do
    (cascaded_groups + [unrelated_group]).each do |namespace|
      namespace.namespace_settings.update!(built_in_project_templates_enabled: false)
    end

    allow(Gitlab::Metrics::RuntimeLimiter).to receive(:new).and_return(limiter)

    stub_const("#{described_class}::BATCH_SIZE", 2)
  end

  describe '#perform' do
    subject(:perform) { worker.perform(group_id, built_in_project_templates_enabled, cursor) }

    let(:cursor) { nil }

    it 'initializes namespace traversal from the group id and updates the group hierarchy' do
      expect(described_class).not_to receive(:perform_in)

      perform

      expect(namespace_settings_value_for(cascaded_groups)).to all(be(true))
      expect(unrelated_group.namespace_settings.reload.built_in_project_templates_enabled).to be(false)
    end

    it 'logs metadata' do
      expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
        over_time: false,
        final_cursor: nil
      })

      perform
    end

    context 'when the group does not exist' do
      let(:group_id) { non_existing_record_id }
      let(:service) { instance_double(::Namespaces::CascadeBuiltInProjectTemplatesEnabledService) }

      it 'does not raise an exception or call the service' do
        expect(::Namespaces::CascadeBuiltInProjectTemplatesEnabledService).to receive(:new)
          .with(built_in_project_templates_enabled)
          .and_return(service)
        expect(service).not_to receive(:update_namespace_settings)

        expect { perform }.not_to raise_error
      end
    end

    context 'when a cursor is provided' do
      let(:cursor) { { 'current_id' => child_group_1.id, 'depth' => [group.id, child_group_1.id] } }

      it 'resumes traversal from the provided cursor' do
        expect(described_class).not_to receive(:perform_in)

        perform

        expect(group.namespace_settings.reload.built_in_project_templates_enabled).to be(false)
        expect(namespace_settings_value_for([child_group_1, child_group_2, descendant_group])).to all(be(true))
        expect(unrelated_group.namespace_settings.reload.built_in_project_templates_enabled).to be(false)
      end
    end

    context 'when over time', :sidekiq_inline do
      let(:expected_cursor) do
        { current_id: descendant_group.id, depth: [group.id, child_group_1.id, descendant_group.id] }
      end

      before do
        allow(limiter).to receive(:over_time?).and_return(true, false)
        allow(limiter).to receive(:was_over_time?).and_return(true)
      end

      it 're-enqueues itself with the iterator cursor' do
        expect(described_class).to receive(:perform_in)
          .with(described_class::RETRY_DELAY, group.id, built_in_project_templates_enabled, expected_cursor)
          .and_call_original

        perform

        expect(namespace_settings_value_for(cascaded_groups)).to all(be(true))
        expect(unrelated_group.namespace_settings.reload.built_in_project_templates_enabled).to be(false)
      end

      it 'logs metadata' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:result, {
          over_time: true,
          final_cursor: expected_cursor
        })

        perform
      end
    end
  end

  def namespace_settings_value_for(namespaces)
    NamespaceSetting.where(namespace: namespaces).map do |namespace_setting|
      namespace_setting.read_attribute(:built_in_project_templates_enabled)
    end
  end
end
