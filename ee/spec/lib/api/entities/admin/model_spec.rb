# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Admin::Model, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  context 'with Geo models' do
    where(model_classes: Gitlab::Geo::ModelMapper.available_models)

    with_them do
      let(:entity) { described_class.new(model, request: double) }
      let(:model) { create(factory_name(model_classes)) } # rubocop:disable Rails/SaveBang -- this is creating a factory, not a record

      subject(:result) { entity.as_json }

      context 'when Geo is enabled' do
        before do
          allow(::Gitlab::Geo).to receive(:enabled?).and_return(true)
        end

        context 'when verification is enabled' do
          before do
            allow(model_classes.replicator_class).to receive(:verification_enabled?).and_return(true)
          end

          it 'returns the expected data' do
            expect(result[:record_identifier]).to eq(model.id)
            expect(result[:model_class]).to eq(model_classes.name)
            expect(result[:created_at]).to eq(model.respond_to?(:created_at) ? model.created_at : nil)
            expect(result[:file_size]).to eq(model.attributes.has_key?('size') ? model.size : nil)
            expect(result.dig(:checksum_information, :checksum_state))
              .to eq(model.verification_state_name_no_prefix)
          end
        end

        context 'when verification is disabled' do
          before do
            allow(model_classes.replicator_class).to receive(:verification_enabled?).and_return(false)
          end

          it 'returns the expected data' do
            expect(result[:record_identifier]).to eq(model.id)
            expect(result[:model_class]).to eq(model_classes.name)
            expect(result[:created_at]).to eq(model.respond_to?(:created_at) ? model.created_at : nil)
            expect(result[:checksum_information]).to be_nil
          end
        end
      end

      context 'when Geo is disabled' do
        before do
          allow(::Gitlab::Geo).to receive(:enabled?).and_return(false)
        end

        it 'returns the expected data' do
          expect(result[:record_identifier]).to eq(model.id)
          expect(result[:model_class]).to eq(model_classes.name)
          expect(result[:created_at]).to eq(model.respond_to?(:created_at) ? model.created_at : nil)
          expect(result[:checksum_information]).to be_nil
        end
      end
    end
  end

  context 'with non-geo models' do
    let(:model) { create(:label) }
    let(:entity) { described_class.new(model, request: double) }

    subject(:result) { entity.as_json }

    it 'returns the expected data' do
      expect(result[:record_identifier]).to eq(model.id)
      expect(result[:model_class]).to eq(model.class.name)
      expect(result[:checksum_information]).to be_nil
    end
  end

  context 'with a model which has a composite primary key' do
    let(:model) { create(:virtual_registries_packages_maven_cache_remote_entry) }
    let(:entity) { described_class.new(model, request: double) }
    let(:expected_id) do
      Base64.urlsafe_encode64(model.class.primary_key.map do |field|
        model.read_attribute_before_type_cast(field)
      end.join(' '))
    end

    subject(:result) { entity.as_json }

    it 'returns the expected data' do
      expect(result[:record_identifier]).to eq(expected_id)
      expect(result[:model_class]).to eq(model.class.name)
      expect(result[:checksum_information]).to be_nil
    end
  end
end
