# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../lib/generators/geo/replicator/naming'

RSpec.describe Geo::Replicator::Naming, feature_category: :geo_replication do
  subject(:naming) do
    described_class.new(
      file_name: 'cool_widget', class_name: 'CoolWidget', model_class: 'Ci::SecureFile',
      upload_partition: false, parent_factory: nil
    )
  end

  it 'derives names from file_name and class_name', :aggregate_failures do
    expect(naming).to have_attributes(
      registry_table_name: 'cool_widget_registry',
      state_table_name: 'cool_widget_states',
      foreign_key_name: 'cool_widget_id',
      registry_class_name: 'CoolWidgetRegistry',
      replicator_class_name: 'CoolWidgetReplicator',
      state_class_name: 'CoolWidgetState',
      finder_class_name: 'CoolWidgetRegistryFinder',
      resolver_class_name: 'CoolWidgetRegistriesResolver',
      registry_type_class_name: 'CoolWidgetRegistryType',
      enum_key: 'COOL_WIDGET_REGISTRY',
      graphql_field_name: 'cool_widget_registries',
      graphql_field_name_camel: 'coolWidget',
      graphql_registries_field_camel: 'coolWidgetRegistries',
      graphql_foreign_key_field_camel: 'coolWidgetId',
      replication_feature_flag_name: 'geo_cool_widget_replication',
      force_primary_checksumming_feature_name: 'geo_cool_widget_force_primary_checksumming',
      replicable_title: 'Cool Widget',
      replicable_title_plural: 'Cool Widgets',
      model_factory_name: 'secure_file' # demodulized + underscored from the model class
    )
  end

  describe '#registry_factory_replicable_name' do
    it 'prefixes geo_ only in upload-partition mode', :aggregate_failures do
      expect(naming.registry_factory_replicable_name).to eq('cool_widget')

      partitioned = described_class.new(
        file_name: 'cool_widget', class_name: 'CoolWidget', model_class: 'CoolWidget',
        upload_partition: true, parent_factory: nil
      )
      expect(partitioned.registry_factory_replicable_name).to eq('geo_cool_widget')
    end
  end

  describe '#parent_model_factory_name' do
    it 'defaults to the name minus _upload and is overridable', :aggregate_failures do
      default = described_class.new(
        file_name: 'cool_widget_upload', class_name: 'CoolWidgetUpload',
        model_class: 'CoolWidgetUpload', upload_partition: true, parent_factory: nil
      )
      expect(default.parent_model_factory_name).to eq('cool_widget')

      overridden = described_class.new(
        file_name: 'cool_widget_upload', class_name: 'CoolWidgetUpload',
        model_class: 'CoolWidgetUpload', upload_partition: true, parent_factory: 'widget'
      )
      expect(overridden.parent_model_factory_name).to eq('widget')
    end
  end
end
