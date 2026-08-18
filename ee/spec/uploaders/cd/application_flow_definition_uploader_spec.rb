# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Cd::ApplicationFlowDefinitionUploader, feature_category: :continuous_delivery do
  let_it_be(:flow_definition) { create(:cd_application_flow_definition) }

  let(:uploader) { described_class.new(flow_definition, :file) }

  subject { uploader }

  it_behaves_like "builds correct paths",
    store_dir: %r{\Auploads/-/system/\h{2}/\h{2}/\h{64}/cd_application_flow_definitions/\d+\z},
    cache_dir: %r{/uploads/-/system/tmp/cache\z},
    work_dir: %r{/uploads/-/system/tmp/work\z}

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
    context 'when the model is not persisted' do
      let(:flow_definition) { build(:cd_application_flow_definition) }

      it 'raises ObjectNotReadyError' do
        expect { uploader.store_dir }.to raise_error(
          GitlabUploader::ObjectNotReadyError,
          'ApplicationFlowDefinition model not ready'
        )
      end
    end

    context 'when organization_id is nil' do
      before do
        allow(flow_definition).to receive(:organization_id).and_return(nil)
      end

      it 'raises ObjectNotReadyError' do
        expect { uploader.store_dir }.to raise_error(
          GitlabUploader::ObjectNotReadyError,
          'ApplicationFlowDefinition model not ready'
        )
      end
    end
  end

  describe '#filename' do
    context 'when a file has been uploaded' do
      before do
        uploader.store!(CarrierWaveStringFile.new('steps: []'))
      end

      after do
        uploader.remove!
      end

      it 'returns definition.yml' do
        expect(uploader.filename).to eq('definition.yml')
      end
    end

    context 'when no file has been uploaded' do
      let(:uploader) { described_class.new(build(:cd_application_flow_definition), :file) }

      it 'returns nil' do
        expect(uploader.filename).to be_nil
      end
    end
  end
end
