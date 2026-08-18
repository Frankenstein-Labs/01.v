# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Instance::AmazonS3Configuration, feature_category: :audit_events do
  describe 'validations' do
    let_it_be(:s3_configuration) { create(:instance_amazon_s3_configuration) }

    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:bucket_name) }
    it { is_expected.to validate_uniqueness_of(:bucket_name) }
    it { is_expected.to validate_presence_of(:access_key_xid) }
    it { is_expected.to validate_presence_of(:aws_region) }
    it { is_expected.to validate_presence_of(:secret_access_key) }
    it { is_expected.to validate_length_of(:access_key_xid).is_at_least(16).is_at_most(128) }
    it { is_expected.to validate_length_of(:aws_region).is_at_most(50) }
    it { is_expected.to validate_length_of(:bucket_name).is_at_most(63) }
    it { is_expected.to allow_value("valid-bucket-name").for(:bucket_name) }
    it { is_expected.to allow_value("12345").for(:bucket_name) }
    it { is_expected.not_to allow_value("bucket/logs/test").for(:bucket_name) }
    it { is_expected.not_to allow_value("<script>").for(:access_key_xid) }
    it { is_expected.to allow_value("RANDOM1234567890").for(:access_key_xid) }

    it_behaves_like 'includes AwsExternallyDestinationable concern' do
      let(:model_factory_name) { :instance_amazon_s3_configuration }
    end
  end

  it_behaves_like 'includes Limitable concern' do
    subject { build(:instance_amazon_s3_configuration) }
  end

  it_behaves_like 'includes ExternallyCommonDestinationable concern' do
    let(:model_factory_name) { :instance_amazon_s3_configuration }
  end

  it_behaves_like 'includes InstanceStreamDestinationMappable concern',
    let(:model_factory_name) { :instance_amazon_s3_configuration }

  it_behaves_like 'includes Activatable concern' do
    let(:model_factory_name) { :instance_amazon_s3_configuration }
  end

  describe '#allowed_to_stream?' do
    let(:s3_configuration) { create(:instance_amazon_s3_configuration) }

    it 'always returns true' do
      expect(s3_configuration.allowed_to_stream?).to be(true)
    end
  end
end
