# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Gitlab::Geo::Replication::BlobRetriever, :aggregate_failures, feature_category: :geo_replication do
  include EE::GeoHelpers

  let_it_be(:primary, freeze: true) { create(:geo_node, :primary) }

  let(:package_file) do
    file = create(:package_file, :npm)
    checksum = file.class.sha256_hexdigest(file.file.path)
    file.update_column(:verification_checksum, checksum)
    file
  end

  let(:package_checksum) { package_file.verification_checksum }
  let(:replicator_class) { Geo::PackageFileReplicator }
  let(:replicator) { replicator_class.new(model_record_id: package_file.id) }

  before do
    stub_current_geo_node(primary)
  end

  describe '#initialize' do
    it 'errors out with an invalid replicator' do
      expect { described_class.new(replicator: Object.new, checksum: nil) }.to raise_error(ArgumentError)
    end

    it 'accepts valid attributes' do
      expect { described_class.new(replicator: replicator, checksum: nil) }.not_to raise_error
      expect { described_class.new(replicator: replicator, checksum: package_checksum) }.not_to raise_error
    end
  end

  describe '#execute' do
    subject { described_class.new(replicator: replicator, checksum: package_checksum) }

    it 'returns model not found error if record cant be found' do
      subject = described_class.new(replicator: replicator_class.new(model_record_id: 1234567890), checksum: nil)
      response = subject.execute

      expect(response).to include(code: :not_found)
      expect(response).to include(message: /package_file not found/)
    end

    it 'returns file not found if file cant be found' do
      subject
      File.unlink(package_file.file.path)

      response = subject.execute

      expect(response).to include(code: :not_found)
      expect(response).to include(message: /file not found/)
    end

    it 'returns checksum mismatch if sending an invalid checksum' do
      subject = described_class.new(replicator: replicator, checksum: 'invalid')
      response = subject.execute

      expect(response).to include(code: :not_found)
      expect(response).to include(message: 'Checksum mismatch')
    end

    it 'works with valid attributes' do
      response = subject.execute

      expect(response).to include(code: :ok)
      expect(response).to include(message: 'Success')
      expect(response[:file].path).to eq(package_file.file.path)
      expect(response[:file]).to be_a(GitlabUploader)
    end
  end
end
