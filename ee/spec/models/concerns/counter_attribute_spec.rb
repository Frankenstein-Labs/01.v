# frozen_string_literal: true

require 'spec_helper'

# We need to assert the behavior with a model that has a group_id column.
# The only model with those conditions is only available on the EE side.
# When a model with similar aspects is available on CE, merge this spec with the CE spec.
RSpec.describe CounterAttribute, :counter_attribute, feature_category: :shared do
  describe '#counters_key_prefix' do
    subject(:prefix) { model.counters_key_prefix }

    context 'with a model that has a project_id' do
      let(:model) { CounterAttributeModel.find(create(:project_statistics).id) }

      it { is_expected.to eq("project:{#{model.project_id}}") }
    end

    context 'with a model that has a group_id' do
      let(:model) { create(:virtual_registries_packages_maven_cache_remote_entry) }

      it { is_expected.to eq("group:{#{model.group_id}}") }
    end

    context 'with a model that does not have a project_id nor a group_id' do
      let(:model) do
        Class.new do
          def self.after_commit(_); end
          def self.after_rollback(_); end
        end.include(described_class).new
      end

      it 'raises an error' do
        expect { prefix }
          .to raise_error(ArgumentError, 'counter record must have either a project_id or a group_id column')
      end
    end
  end
end
