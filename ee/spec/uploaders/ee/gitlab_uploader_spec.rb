# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabUploader, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  before_all do
    create_dummy_model_table
  end

  after(:all) do
    drop_dummy_model_table
  end

  before do
    stub_dummy_replicator_class
    stub_dummy_model_class
  end

  let(:model) { DummyModel.new }
  let(:uploader) { described_class.new(model) }

  describe '#migrate!' do
    before do
      stub_primary_site
    end

    it 'calls recalculate_checksum_for_geo after migration' do
      expect(uploader).to receive(:recalculate_checksum_for_geo)

      uploader.send(:with_callbacks, :migrate, nil) { nil }
    end
  end

  describe '#recalculate_checksum_for_geo' do
    context 'when on a Geo primary site' do
      before do
        stub_primary_site
      end

      context 'when model supports verification_pending!' do
        it 'marks verification as pending' do
          expect(model).to receive(:verification_pending!)

          uploader.recalculate_checksum_for_geo
        end
      end

      context 'when model does not support verification_pending!' do
        before do
          allow(model).to receive(:respond_to?).with(:verification_pending!).and_return(false)
        end

        it 'does nothing' do
          expect(model).not_to receive(:verification_pending!)

          uploader.recalculate_checksum_for_geo
        end
      end
    end

    context 'when not on a Geo primary site' do
      before do
        stub_secondary_site
      end

      it 'does nothing' do
        expect(model).not_to receive(:verification_pending!)

        uploader.recalculate_checksum_for_geo
      end
    end
  end
end
