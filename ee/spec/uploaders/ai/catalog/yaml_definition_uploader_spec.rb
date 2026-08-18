# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::YamlDefinitionUploader, feature_category: :ai_agents do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, :flow, project: project) }
  let_it_be_with_reload(:item_version) { create(:ai_catalog_flow_version, item: item) }

  let(:uploader) { described_class.new(item_version) }

  subject { uploader }

  it_behaves_like "builds correct paths",
    store_dir: %r{\A\h{2}/\h{2}/\h{64}/yaml_definitions/\d+\z},
    cache_dir: %r{/ai_catalog/tmp/cache\z},
    work_dir: %r{/ai_catalog/tmp/work\z}

  describe '.default_store' do
    context 'when object storage is enabled' do
      before do
        allow(described_class).to receive(:object_store_enabled?).and_return(true)
      end

      it 'returns REMOTE' do
        expect(described_class.default_store).to eq(ObjectStorage::Store::REMOTE)
      end
    end

    context 'when object storage is disabled' do
      before do
        allow(described_class).to receive(:object_store_enabled?).and_return(false)
      end

      it 'returns LOCAL' do
        expect(described_class.default_store).to eq(ObjectStorage::Store::LOCAL)
      end
    end
  end

  describe '#store_dir' do
    context 'when model is not persisted' do
      let(:item_version) { build(:ai_catalog_flow_version, item: item) }

      it 'raises ObjectNotReadyError' do
        expect { uploader.store_dir }.to raise_error(
          GitlabUploader::ObjectNotReadyError,
          "ItemVersion model not ready"
        )
      end
    end

    context 'when organization_id is nil' do
      before do
        allow(item_version).to receive(:organization_id).and_return(nil)
      end

      it 'raises ObjectNotReadyError' do
        expect { uploader.store_dir }.to raise_error(
          GitlabUploader::ObjectNotReadyError,
          "ItemVersion model not ready"
        )
      end
    end

    context 'when organization_id differs' do
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:other_project) { create(:project, organization: other_organization) }
      let_it_be_with_reload(:other_item) do
        create(:ai_catalog_item, :flow, project: other_project, organization: other_organization)
      end

      let_it_be_with_reload(:other_item_version) { create(:ai_catalog_flow_version, item: other_item) }

      let(:other_uploader) { described_class.new(other_item_version) }

      it 'produces different store_dir paths based on root_hash' do
        expect(uploader.store_dir.to_s).not_to eq(other_uploader.store_dir.to_s)
      end
    end
  end

  describe '#filename' do
    context 'when a file has been uploaded' do
      before do
        uploader.store!(CarrierWaveStringFile.new('test content'))
      end

      after do
        uploader.remove!
      end

      it 'returns definition.yml' do
        expect(uploader.filename).to eq('definition.yml')
      end
    end

    context 'when no file has been uploaded' do
      it 'returns nil' do
        expect(uploader.filename).to be_nil
      end
    end
  end
end
