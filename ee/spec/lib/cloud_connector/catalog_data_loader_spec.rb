# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::CatalogDataLoader, feature_category: :plan_provisioning do
  let(:model_class) { Gitlab::CloudConnector::DataModel::UnitPrimitive }

  subject(:catalog_loader) { described_class.new(model_class) }

  describe '#load_with_index!' do
    let(:loader_instance) { instance_double(::Gitlab::CloudConnector::DataModel::YamlDataLoader) }
    let(:expected_result) { { test_unit_primitive: instance_double(model_class) } }

    before do
      allow(catalog_loader).to receive(:loader).and_return(loader_instance)
      allow(loader_instance).to receive(:load_with_index!).and_return(expected_result)
    end

    it 'delegates to the selected loader instance' do
      result = catalog_loader.load_with_index!
      expect(result).to eq(expected_result)
    end
  end

  describe '#loader' do
    shared_examples 'returns expected loader class' do |expected_class|
      it "returns #{expected_class}" do
        expect(catalog_loader.loader).to be_an_instance_of(expected_class)
      end
    end

    context 'when on gitlab.com', :saas do
      include_examples 'returns expected loader class', Gitlab::CloudConnector::DataModel::YamlDataLoader
    end

    context 'when offline license is used' do
      before do
        create_current_license(cloud_licensing_enabled: true, offline_cloud_licensing_enabled: true)
      end

      include_examples 'returns expected loader class', Gitlab::CloudConnector::DataModel::YamlDataLoader
    end

    context 'when ENV var is set to true' do
      before do
        stub_env('CLOUD_CONNECTOR_SELF_SIGN_TOKENS', '1')
      end

      include_examples 'returns expected loader class', Gitlab::CloudConnector::DataModel::YamlDataLoader
    end

    context 'when License.current is nil' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      include_examples 'returns expected loader class', Gitlab::CloudConnector::DataModel::YamlDataLoader
    end

    context 'when none of the YAML conditions apply' do
      include_examples 'returns expected loader class', CloudConnector::DatabaseDataLoader
    end

    describe "#license changes" do
      it 'dynamically changes loader based on the license' do
        expect(catalog_loader.loader).to be_an_instance_of(CloudConnector::DatabaseDataLoader)

        allow(License).to receive(:current).and_return(nil)

        expect(catalog_loader.loader).to be_an_instance_of(Gitlab::CloudConnector::DataModel::YamlDataLoader)
      end
    end

    describe '#loader memoization' do
      shared_examples 'memoized loader' do
        let(:expected_loader_class) do
          use_yaml_loader ? ::Gitlab::CloudConnector::DataModel::YamlDataLoader : ::CloudConnector::DatabaseDataLoader
        end

        before do
          allow(catalog_loader).to receive(:use_yaml_data_loader?).and_return(use_yaml_loader)
        end

        it "memoizes the loader class" do
          expect(expected_loader_class).to receive(:new)
            .once
            .with(model_class)
            .and_call_original

          loader1 = catalog_loader.loader
          loader2 = catalog_loader.loader

          expect(loader1).to equal(loader2)
        end
      end

      context 'with yaml_data_loader' do
        let(:use_yaml_loader) { true }

        include_examples 'memoized loader'
      end

      context 'with database_data_loader' do
        let(:use_yaml_loader) { false }

        include_examples 'memoized loader'
      end
    end
  end
end
