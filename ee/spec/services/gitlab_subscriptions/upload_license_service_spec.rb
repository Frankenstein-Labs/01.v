# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::UploadLicenseService, feature_category: :plan_provisioning do
  subject(:execute_service) { described_class.new(params, path_to_subscription_page).execute }

  let(:path_to_subscription_page) { '/admin/subscription' }
  let(:params) { { data: build(:license, data: gitlab_license.export).data } }

  shared_examples 'license creation result' do |status:, persisted:|
    it "returns #{status == :success ? 'a success' : 'an error'}" do
      result = execute_service
      license = result.payload[:license]

      expect(result.status).to eq(status)
      expect(license).to be_an_instance_of(License)
      expect(license.persisted?).to eq(persisted)
      expect(result.message).to eq(message)
    end
  end

  shared_examples 'unsuccessful license upload scenarios' do
    context 'with an invalid license key' do
      let(:params) { { data: 'invalid_license_key' } }
      let(:message) { 'The license key is invalid. Make sure it is exactly as you received it from GitLab Inc.' }

      include_examples 'license creation result', status: :error, persisted: false
    end

    context 'with an expired license key' do
      let(:license_traits) { super() << :expired }
      let(:message) { 'This license has already expired.' }

      include_examples 'license creation result', status: :error, persisted: false
    end
  end

  shared_examples 'successful license upload scenarios' do
    let(:message) { 'The license was successfully uploaded and is now active. You can see the details below.' }

    context 'and the license has already started' do
      let(:attributes) { { starts_at: Date.yesterday } }

      include_examples 'license creation result', status: :success, persisted: true
    end

    context 'and the license starts today' do
      let(:attributes) { { starts_at: Date.current } }

      include_examples 'license creation result', status: :success, persisted: true
    end

    context 'and the license has a future start date' do
      let(:start_date) { Date.tomorrow }
      let(:attributes) { { starts_at: start_date } }
      let(:message) do
        "The license was successfully uploaded and will be active from #{start_date}. You can see the details below."
      end

      include_examples 'license creation result', status: :success, persisted: true
    end

    context 'and is uploaded via a file' do
      let(:params) { { data_file: temp_file } }
      let(:temp_file) do
        license_key = build(:license, data: gitlab_license.export).data

        Tempfile.new.tap do |file|
          file.write(license_key)
          file.rewind
        end
      end

      after do
        temp_file.close
        temp_file.unlink
      end

      include_examples 'license creation result', status: :success, persisted: true
    end
  end

  context 'when license key and license file params are missing' do
    let(:params) { {} }
    let(:message) do
      'The license you uploaded is invalid. If the issue persists, contact support at ' \
        '<a href="https://support.gitlab.com">https://support.gitlab.com</a>.'
    end

    include_examples 'license creation result', status: :error, persisted: false
  end

  context 'when license key belongs to an online cloud license' do
    let(:gitlab_license) { build(:gitlab_license, :online) }
    let(:message) do
      "It looks like you're attempting to activate your subscription. Use " \
        "<a href=\"#{path_to_subscription_page}\">the Subscription page</a> instead."
    end

    include_examples 'license creation result', status: :error, persisted: false
  end

  context 'when license key belongs to an offline cloud license' do
    let(:license_traits) { [:offline] }
    let(:attributes) { {} }
    let(:gitlab_license) { build(:gitlab_license, *license_traits, attributes) }

    include_examples 'unsuccessful license upload scenarios'
    include_examples 'successful license upload scenarios'

    it_behaves_like 'call runner to handle the provision of add-ons'
  end

  context 'when license key belongs to a legacy license' do
    let(:license_traits) { [:legacy] }
    let(:attributes) { {} }
    let(:gitlab_license) { build(:gitlab_license, *license_traits, attributes) }

    context 'and for a trial' do
      let(:license_traits) { super() << :trial }

      include_examples 'unsuccessful license upload scenarios'
      include_examples 'successful license upload scenarios'

      it 'does not call the service to process add-on purchases' do
        expect(::GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::AddOns).not_to receive(:new)

        execute_service
      end
    end

    include_examples 'unsuccessful license upload scenarios'
    include_examples 'successful license upload scenarios'

    it 'does not call the service to process add-on purchases' do
      expect(::GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::AddOns).not_to receive(:new)

      execute_service
    end
  end
end
