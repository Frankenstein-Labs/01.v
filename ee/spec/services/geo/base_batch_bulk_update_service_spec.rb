# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BaseBatchBulkUpdateService, feature_category: :geo_replication do
  let(:service) { described_class.new('Upload', {}) }

  shared_examples 'a non implemented method' do |method|
    it 'raises `NotImplementedError`' do
      expect { service.send(method) }.to raise_error(NotImplementedError)
    end
  end

  describe '#attributes_to_update' do
    it_behaves_like 'a non implemented method', :attributes_to_update
  end

  describe '#update_scope' do
    it_behaves_like 'a non implemented method', :update_scope
  end

  describe '#worker' do
    it_behaves_like 'a non implemented method', :worker
  end

  describe '#class_to_update' do
    it_behaves_like 'a non implemented method', :class_to_update
  end

  describe '#records_to_update' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive_messages(model_class: model_to_update,
          update_scope: model_to_update.all,
          class_to_update: model_to_update)
      end
    end

    context 'with a model which has a composite PK' do
      shared_examples 'records_to_update returns an iterator' do
        it 'returns a keyset iterator' do
          expect(service.send(:records_to_update)).to be_an_instance_of(Gitlab::Pagination::Keyset::Iterator)
        end
      end

      context 'when class contains FromUnion' do
        let(:model_to_update) do
          Class.new(VirtualRegistries::Packages::Maven::Cache::Remote::Entry) do
            def self.name
              "VirtualRegistries::Packages::Maven::Cache::Remote::Entry"
            end
            include Geo::VerificationStateDefinition
            include FromUnion
          end
        end

        it_behaves_like 'records_to_update returns an iterator'
      end

      context 'when class does not contain FromUnion' do
        let(:model_to_update) do
          Class.new(VirtualRegistries::Packages::Maven::Cache::Remote::Entry) do
            def self.name
              "VirtualRegistries::Packages::Maven::Cache::Remote::Entry"
            end
            include Geo::VerificationStateDefinition
          end
        end

        it_behaves_like 'records_to_update returns an iterator'
      end
    end

    context 'with a model which has an integer PK' do
      let_it_be(:model_to_update) { Geo::UploadState }

      it 'returns the model' do
        expect(service.send(:records_to_update)).to be_a_kind_of(ActiveRecord::Relation)
      end
    end
  end

  describe '#model_class' do
    context 'with a valid model name' do
      it 'returns the matching class' do
        expect(service.send(:model_class)).to eq(Upload)
      end
    end

    context 'with an invalid model name' do
      let(:service) { described_class.new('invalid', {}) }

      it_behaves_like 'a non implemented method', :model_class
    end
  end
end
