# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::GeoHelper, feature_category: :geo_replication do
  include EE::GeoHelpers

  describe '.current_node_human_status' do
    where(:primary, :secondary, :org_migration_target, :result) do
      [
        [false, false, false, s_('Geo|misconfigured')],
        [false, false, true,  s_('Geo|org migration target cell')],
        [false, true,  false, s_('Geo|secondary')],
        [false, true,  true,  s_('Geo|secondary')],
        [true,  false, false, s_('Geo|primary')],
        [true,  false, true,  s_('Geo|primary')],
        [true,  true,  false, s_('Geo|primary')],
        [true,  true,  true,  s_('Geo|primary')]
      ]
    end

    with_them do
      it 'returns correct results' do
        allow(::Gitlab::Geo).to receive(:primary?).and_return(primary)
        allow(::Gitlab::Geo).to receive(:secondary?).and_return(secondary)
        allow(::Gitlab::Geo).to receive(:org_migration_target?).and_return(org_migration_target)

        expect(described_class.current_node_human_status).to eq result
      end
    end
  end

  describe '#replicable_types' do
    subject(:replicable_types) { helper.replicable_types }

    it 'includes replicable replicators' do
      expected_replicable_types = Gitlab::Geo::REPLICATOR_CLASSES.select(&:replication_enabled?).map do |klass|
        replicable_class_data(klass)
      end

      expect(replicable_types).to include(*expected_replicable_types)
    end

    it 'does not include non replicable replicators' do
      disabled_replicator = Gitlab::Geo::REPLICATOR_CLASSES.find(&:replication_enabled?)
      stub_feature_flags(disabled_replicator.replication_enabled_feature_key => false)

      expect(replicable_types).not_to include(replicable_class_data(disabled_replicator))
    end

    it 'sorts by title' do
      titles = replicable_types.pluck(:title)

      expect(titles).to eq(titles.sort)
    end
  end

  describe '#replicable_class_data' do
    let(:replicator) { Gitlab::Geo.replication_enabled_replicator_classes[0] }

    subject(:replicable_class_data) { helper.replicable_class_data(replicator) }

    it 'returns the correct data map' do
      expect(replicable_class_data).to eq({
        data_type: replicator.data_type,
        data_type_title: replicator.data_type_title,
        data_type_sort_order: replicator.data_type_sort_order,
        title: replicator.replicable_title,
        title_plural: replicator.replicable_title_plural,
        name: replicator.replicable_name,
        name_plural: replicator.replicable_name_plural,
        graphql_field_name: replicator.graphql_field_name,
        graphql_registry_class: replicator.registry_class,
        graphql_mutation_registry_class: replicator.graphql_mutation_registry_class,
        model_class_name: replicator.model.name,
        data_management_url: list_admin_data_management_path(model_name: replicator.model_name.pluralize),
        replication_enabled: replicator.replication_enabled?,
        verification_enabled: replicator.verification_enabled?,
        graphql_registry_id_type: Types::GlobalIDType[replicator.registry_class].to_s
      })
    end
  end

  describe '#format_file_size_for_checksum' do
    context 'when file size is of even length' do
      it 'returns same file size string' do
        expect(helper.format_file_size_for_checksum("12")).to eq("12")
      end
    end

    context 'when file size is of odd length' do
      it 'returns even length file size string with a padded leading zero' do
        expect(helper.format_file_size_for_checksum("123")).to eq("0123")
      end
    end

    context 'when file size is 0' do
      it 'returns even length file size string with a padded leading zero' do
        expect(helper.format_file_size_for_checksum("0")).to eq("00")
      end
    end
  end

  describe '#model_types' do
    subject(:model_types) { helper.model_types }

    it 'includes model_class_data for replicable models' do
      expected_model_types = Gitlab::Geo::REPLICATOR_CLASSES.select(&:replication_enabled?).map do |replicator|
        helper.model_type_data(replicator.model)
      end

      expect(model_types).to include(*expected_model_types)
    end

    it 'does not include non replicable models' do
      disabled_replicator = Gitlab::Geo::REPLICATOR_CLASSES.find(&:replication_enabled?)
      stub_feature_flags(disabled_replicator.replication_enabled_feature_key => false)

      expect(model_types).not_to include(model_type_data(disabled_replicator.model))
    end

    it 'sorts by title' do
      titles = model_types.pluck(:title)

      expect(titles).to eq(titles.sort)
    end
  end

  describe '#admin_data_management_app_data' do
    let(:model) { Project }

    it 'returns expected json' do
      expected_data = {
        model_types: helper.model_types.to_json,
        initial_model_type_name: 'projects',
        base_path: '/admin/data_management'
      }

      expect(helper.admin_data_management_app_data(model)).to eq(expected_data)
    end
  end

  describe '#model_type_data' do
    let(:result) { helper.model_type_data(DummyModel) }

    before do
      stub_dummy_replicator_class
      stub_dummy_model_class
    end

    context 'when model has a replicator' do
      context 'with verification enabled' do
        before do
          allow(::Geo::DummyReplicator).to receive(:verification_enabled?).and_return(true)
        end

        it 'returns model data with checksum enabled' do
          expect(result).to eq({
            title: 'Dummy Model',
            title_plural: 'Dummy Models',
            name: 'dummy_model',
            name_plural: 'dummy_models',
            model_class: 'DummyModel',
            checksum_enabled: true
          })
        end
      end

      context 'with verification disabled' do
        before do
          allow(::Geo::DummyReplicator).to receive(:verification_enabled?).and_return(false)
        end

        it 'returns checksum disabled' do
          expect(result).to include(checksum_enabled: false)
        end
      end
    end

    context 'when model does not have a replicator' do
      before do
        allow(DummyModel).to receive(:respond_to?).with(:replicator_class).and_return(false)
      end

      it 'returns checksum disabled' do
        expect(result).to include(checksum_enabled: false)
      end
    end
  end

  describe '#admin_data_management_item_app_data' do
    let(:model) { build_stubbed(:project) }

    it 'returns expected data' do
      expect(helper.admin_data_management_item_app_data(model)).to eq(
        {
          model_type_data: helper.model_type_data(model.class).to_json,
          model_id: model.id.to_s
        }
      )
    end
  end
end
