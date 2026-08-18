# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::DatabaseDataLoader, feature_category: :plan_provisioning do
  let(:unit_primitive_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }

  subject(:unit_primitive_loader) { described_class.new(unit_primitive_class) }

  describe '#load_with_index!' do
    context 'with valid catalog data' do
      before do
        create(:cloud_connector_access)
      end

      it 'returns a name index (Hash) with correctly instantiated models', :request_store do
        index = unit_primitive_loader.load_with_index!

        expect(index).to be_a(Hash)
        expect(index).not_to be_empty
        expect(index.keys).to all(be_a(Symbol))

        up = index.each_value.first
        expect(up).to be_a(Gitlab::CloudConnector::DataModel::UnitPrimitive)

        expect(up.backend_services).to all(be_instance_of(Gitlab::CloudConnector::DataModel::BackendService))
        expect(up.license_types).to all(be_instance_of(Gitlab::CloudConnector::DataModel::LicenseType))
      end

      it 'parses cut_off_date fields as Time objects when present' do
        index = unit_primitive_loader.load_with_index!
        with_dates = index.values.select(&:cut_off_date)

        expect(with_dates).not_to be_empty
        expect(with_dates.map(&:cut_off_date)).to all(be_a(Time))
      end
    end

    context 'with an empty catalog record' do
      it 'returns an empty Hash' do
        expect(unit_primitive_loader.load_with_index!).to eq({})
      end

      it 'logs a warning' do
        expect(::Gitlab::AppLogger).to receive(:warn).with(
          message: 'Catalog is empty or not synced',
          class_name: described_class.name
        )

        unit_primitive_loader.load_with_index!
      end
    end

    context 'when the model key is missing in the catalog' do
      let(:data_model_class) { Gitlab::CloudConnector::DataModel::Base }
      let(:data_model_loader) { described_class.new(data_model_class) }

      before do
        create(:cloud_connector_access)
      end

      it 'returns an empty Hash' do
        expect(data_model_loader.load_with_index!).to eq({})
      end

      it 'logs a warning' do
        model_name = data_model_class.model_name.tableize
        expect(::Gitlab::AppLogger).to receive(:warn).with(
          message: "Catalog key '#{model_name}' is missing or empty",
          class_name: described_class.name
        )

        data_model_loader.load_with_index!
      end
    end

    context 'when SafeRequestStore caching is enabled', :request_store do
      before do
        create(:cloud_connector_access)
      end

      it 'loads the raw catalog only once even across different model loaders' do
        add_on_loader = described_class.new(Gitlab::CloudConnector::DataModel::AddOn)

        expect(CloudConnector::Access).to receive(:last).once.and_call_original

        unit_primitive_loader.load_with_index!
        add_on_loader.load_with_index!
      end

      it 'uses separate cache keys per model loader and memoizes results per key' do
        add_on_loader = described_class.new(Gitlab::CloudConnector::DataModel::AddOn)

        unit_primitives_index = unit_primitive_loader.load_with_index!
        add_ons_index = add_on_loader.load_with_index!

        allow(CloudConnector::Access).to receive(:last).and_return([])

        expect(unit_primitive_loader.load_with_index!).to be(unit_primitives_index)
        expect(add_on_loader.load_with_index!).to be(add_ons_index)
        expect(unit_primitive_loader.load_with_index!).not_to be(add_on_loader.load_with_index!)
      end
    end
  end
end
