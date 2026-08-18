# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Local::Upstream::File, feature_category: :virtual_registry do
  subject(:file) { build(:virtual_registries_local_upstream_file) }

  let_it_be(:package_file) do
    create(
      :package_file,
      file_md5: '09f7e02f1290be211da707a266f153b8',
      file_sha1: 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd8'
    )
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:global_id) }
    it { is_expected.to validate_presence_of(:file) }
    it { is_expected.to validate_presence_of(:sha1) }
    it { is_expected.to validate_presence_of(:md5) }

    it { is_expected.to allow_value('a94a8fe5ccb19ba61c4c0873d391e987982fbbd6').for(:sha1) }
    it { is_expected.not_to allow_value('a94a8fe5ccb19ba61c4c0873d391e987982fbbd!').for(:sha1) }
    it { is_expected.not_to allow_value('tooshort').for(:sha1) }

    it { is_expected.to allow_value('09f7e02f1290be211da707a266f153b6').for(:md5) }
    it { is_expected.not_to allow_value('09f7e02f1290be211da707a266f153b!').for(:md5) }
    it { is_expected.not_to allow_value('tooshort').for(:md5) }
  end

  describe '.from_raw_local_file' do
    context 'with a package file' do
      subject(:from_raw_local_file) { described_class.from_raw_local_file(package_file) }

      it 'creates the correct local file instance' do
        is_expected.to have_attributes(
          global_id: package_file.to_global_id.to_s,
          raw_file_id: package_file.id,
          file: instance_of(::Packages::PackageFileUploader),
          sha1: package_file.file_sha1,
          md5: package_file.file_md5
        )
      end

      %i[md5 sha1].each do |digest_format|
        context "with invalid #{digest_format}" do
          let_it_be(:package_file) { create(:package_file, "file_#{digest_format}" => "too_short") }

          it 'raise an ArgumentError with validation errors' do
            expect { from_raw_local_file }.to raise_error(ArgumentError) do |error|
              expect(error.message).not_to be_empty
            end
          end
        end
      end
    end

    context 'with a non accepted object class' do
      let_it_be(:project) { create(:project) }

      subject(:from_raw_local_file) { described_class.from_raw_local_file(project) }

      it 'raises an ArgumentError' do
        expect { from_raw_local_file }.to raise_error(ArgumentError, described_class::INVALID_RAW_FILE_TYPE_ERROR)
      end
    end
  end

  describe '#content_type' do
    subject { file.content_type }

    it { is_expected.to eq(file.file.content_type) }
  end

  describe 'eql?' do
    let(:file) { described_class.from_raw_local_file(package_file) }
    let(:other_file) { described_class.from_raw_local_file(package_file) }

    subject { file.eql?(other_file) }

    it { is_expected.to be_truthy }

    context 'when other is not a File instance' do
      let(:other_file) { 'not a file' }

      it { is_expected.to be_falsey }
    end
  end

  describe '#hash' do
    let(:file) { described_class.from_raw_local_file(package_file) }
    let(:other_file) { described_class.from_raw_local_file(package_file) }

    it 'returns the same hash for equal objects' do
      expect(file.hash).to eq(other_file.hash)
    end
  end

  describe '#digests' do
    let(:file) { described_class.from_raw_local_file(package_file) }

    subject { file.digests }

    it { is_expected.to eq({ sha1: package_file.file_sha1, md5: package_file.file_md5 }) }
  end
end
