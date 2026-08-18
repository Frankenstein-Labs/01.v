# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::CascadeBuiltInProjectTemplatesEnabledService, feature_category: :source_code_management do
  let_it_be_with_reload(:namespace_1) { create(:namespace, :with_namespace_settings) }
  let_it_be_with_reload(:namespace_2) { create(:namespace, :with_namespace_settings) }
  let_it_be_with_reload(:namespace_3) { create(:namespace, :with_namespace_settings) }
  let_it_be_with_reload(:namespace_4) { create(:namespace, :with_namespace_settings) }

  let(:namespaces) { [namespace_1, namespace_2, namespace_3, namespace_4] }

  let(:namespace_ids) do
    NamespaceSetting
      .where(namespace_id: namespaces.map(&:id))
      .order(:namespace_id)
      .pluck(:namespace_id)
  end

  let(:limit) { 2 }
  let(:built_in_project_templates_enabled) { true }
  let(:initial_built_in_project_templates_enabled) { false }

  subject(:service) { described_class.new(built_in_project_templates_enabled) }

  before do
    namespaces.each do |g|
      g.namespace_settings.update!(built_in_project_templates_enabled: initial_built_in_project_templates_enabled)
    end
  end

  describe '#update_namespace_settings' do
    subject(:update_namespace_settings) { service.update_namespace_settings(namespace_ids.first(2)) }

    it 'updates only the provided namespaces' do
      expect { update_namespace_settings }
        .to change { built_in_project_templates_enabled_value(namespace_ids.first) }.from(false).to(true)
        .and change { built_in_project_templates_enabled_value(namespace_ids.second) }.from(false).to(true)
        .and not_change { built_in_project_templates_enabled_value(namespace_ids.third) }
        .and not_change { built_in_project_templates_enabled_value(namespace_ids.fourth) }
    end
  end

  describe '#update_instance_batch' do
    let(:cursor) { namespace_ids.first }

    subject(:update_instance_batch) { service.update_instance_batch(cursor: cursor, limit: limit) }

    context 'with total records greater than the batch size' do
      it 'updates only the batch after the cursor and within the limit' do
        expect { update_instance_batch }
          .to not_change { built_in_project_templates_enabled_value(namespace_ids.first) }
          .and change { built_in_project_templates_enabled_value(namespace_ids.second) }.from(false).to(true)
          .and change { built_in_project_templates_enabled_value(namespace_ids.third) }.from(false).to(true)
          .and not_change { built_in_project_templates_enabled_value(namespace_ids.fourth) }
      end

      it 'returns the cursor of the next batch' do
        expect(update_instance_batch).to eq(namespace_ids.third)
      end
    end

    context 'with total records less than the batch size' do
      let(:limit) { 5 }
      let(:cursor) { 0 }

      it 'updates all records' do
        expect { update_instance_batch }
          .to change { built_in_project_templates_enabled_value(namespace_ids.first) }.from(false).to(true)
          .and change { built_in_project_templates_enabled_value(namespace_ids.second) }.from(false).to(true)
          .and change { built_in_project_templates_enabled_value(namespace_ids.third) }.from(false).to(true)
          .and change { built_in_project_templates_enabled_value(namespace_ids.fourth) }.from(false).to(true)
      end
    end

    context 'when the cursor is the last record' do
      let(:cursor) { namespace_ids.last }

      it 'returns nil' do
        expect(update_instance_batch).to be_nil
      end
    end

    context 'when the cursor is past the last record' do
      let(:cursor) { namespace_ids.last + 10 }

      it 'returns nil' do
        expect(update_instance_batch).to be_nil
      end
    end

    context 'with no cursor' do
      subject(:update_instance_batch) { service.update_instance_batch(limit: limit) }

      it 'updates the first batch' do
        expect { update_instance_batch }
          .to change { built_in_project_templates_enabled_value(namespace_ids.first) }.from(false).to(true)
          .and change { built_in_project_templates_enabled_value(namespace_ids.second) }.from(false).to(true)
          .and not_change { built_in_project_templates_enabled_value(namespace_ids.third) }
      end
    end
  end

  def built_in_project_templates_enabled_value(namespace_id)
    NamespaceSetting.find_by(namespace_id: namespace_id).read_attribute(:built_in_project_templates_enabled)
  end
end
