# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::ModelMapper, feature_category: :geo_replication do
  shared_examples 'a request-store cached method' do
    let(:cache_sentinel_class) { Gitlab::Geo::REPLICATOR_CLASSES.first }
    let(:cache_sentinel_method) { :model }

    context 'with request store', :request_store do
      it 'caches the result within a request' do
        expect(cache_sentinel_class).to receive(cache_sentinel_method).once.and_call_original

        subject_method
        subject_method
      end

      it 'recomputes the result across requests' do
        subject_method
        Gitlab::SafeRequestStore.clear!

        expect(cache_sentinel_class).to receive(cache_sentinel_method).once.and_call_original
        subject_method
      end
    end
  end

  describe '.convert_to_name' do
    let(:model) { class_double(ApplicationRecord, name:) }

    context 'with single word model names' do
      let(:name) { 'User' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('user')
      end
    end

    context 'with multiple word model names' do
      let(:name) { 'ProjectRepository' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('project_repository')
      end
    end

    context 'with namespaced model names' do
      let(:name) { 'Analytics::DevopsAdoption::Segment' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('analytics_devops_adoption_segment')
      end
    end

    context 'with single character name' do
      let(:name) { 'A' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('a')
      end
    end

    context 'with consecutive capitals' do
      let(:name) { 'XMLParser' }

      it 'handles names with consecutive capitals' do
        expect(described_class.convert_to_name(model)).to eq('xml_parser')
      end
    end
  end

  describe '.available_model_names_pluralized' do
    it_behaves_like 'a request-store cached method' do
      def subject_method
        described_class.available_model_names_pluralized
      end
    end

    it 'returns alphanumeric model names' do
      names = described_class.available_model_names_pluralized
      expect(names).not_to be_empty
      expect(names).to all(be_a(String).and(match(/\A[a-z][a-z0-9_]*\z/)))
    end

    it 'has the same count as available model names' do
      expect(described_class.available_model_names_pluralized.size)
        .to eq(described_class.available_model_names.size)
    end

    it 'returns names that differ from their singular form' do
      expect(described_class.available_model_names_pluralized)
        .not_to eq(described_class.available_model_names)
    end

    it 'returns a frozen array' do
      expect(described_class.available_model_names_pluralized).to be_frozen
    end
  end

  describe '.find_from_name' do
    context 'when model name is valid' do
      where(:replicator) { Gitlab::Geo::REPLICATOR_CLASSES }
      with_them do
        let(:model) { replicator.model }
        let(:name) { replicator.model_name }

        it 'returns the correct model for simple names' do
          expect(described_class.find_from_name(name)).to eq(model)
        end

        it 'finds the model regardless of case' do
          expect(described_class.find_from_name(name.upcase)).to eq(model)
        end

        it_behaves_like 'a request-store cached method' do
          # `name` above calls `replicator.model`, so the sentinel must be a
          # different class or that call would be double-counted.
          let(:cache_sentinel_class) { Gitlab::Geo::REPLICATOR_CLASSES.find { |klass| klass != replicator } }

          def subject_method
            described_class.find_from_name(name)
          end
        end
      end
    end

    context 'when model name does not exist' do
      it 'returns nil for non-existent model names' do
        expect(described_class.find_from_name('non_existent_model')).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.find_from_name('')).to be_nil
      end

      it 'returns nil for nil input' do
        expect(described_class.find_from_name(nil)).to be_nil
      end
    end

    context 'when no replicators are available' do
      before do
        stub_const("Gitlab::Geo::REPLICATOR_CLASSES", [])
      end

      it 'returns nil when no models are available' do
        expect(described_class.find_from_name('user')).to be_nil
      end
    end
  end

  describe '.available_models' do
    it 'returns a non-empty list of unique ActiveRecord model classes' do
      models = described_class.available_models
      expect(models).not_to be_empty
      expect(models).to all(be < ActiveRecord::Base)
      expect(models).to eq(models.uniq)
    end

    it_behaves_like 'a request-store cached method' do
      def subject_method
        described_class.available_models
      end
    end
  end

  describe '.available_model_names' do
    it 'returns a non-empty list of snake_case strings' do
      names = described_class.available_model_names
      expect(names).not_to be_empty
      expect(names).to all(be_a(String).and(match(/\A[a-z][a-z0-9_]*\z/)))
    end

    it 'has a name for every available model' do
      expect(described_class.available_model_names.size).to eq(described_class.available_models.size)
    end

    it_behaves_like 'a request-store cached method' do
      def subject_method
        described_class.available_model_names
      end
    end
  end

  describe '.available_replicable_models' do
    it 'returns a non-empty list of unique ActiveRecord model classes' do
      models = described_class.available_replicable_models
      expect(models).not_to be_empty
      expect(models).to all(be < ActiveRecord::Base)
      expect(models).to eq(models.uniq)
    end

    it 'does not include non-replicable models' do
      disabled_replicator = Gitlab::Geo::REPLICATOR_CLASSES.find(&:replication_enabled?)
      stub_feature_flags(disabled_replicator.replication_enabled_feature_key => false)

      models = described_class.available_replicable_models

      expect(models).not_to include(disabled_replicator.model)
    end

    it_behaves_like 'a request-store cached method' do
      let(:cache_sentinel_class) { Gitlab::Geo }
      let(:cache_sentinel_method) { :replication_enabled_replicator_classes }

      def subject_method
        described_class.available_replicable_models
      end
    end
  end
end
