# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicies::CreateService, feature_category: :security_policy_management do
  let(:project) { create(:project) }
  let(:params) { { name: 'ExamplePL/2.1', approval_status: 'denied' } }

  let(:user) do
    create(:user).tap do |u|
      project.add_maintainer(u)
    end
  end

  before do
    stub_licensed_features(license_scanning: true)
  end

  subject(:service) { described_class.new(project, user, params) }

  describe '#execute' do
    shared_examples_for 'find or creates a custom software license' do
      it 'calls CustomSoftwareLicense::FindOrCreateService' do
        expect_next_instance_of(Security::CustomSoftwareLicenses::FindOrCreateService, project: project,
          params: params) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        result
      end

      it 'sets the custom software license' do
        result

        expect(result[:software_license_policy].custom_software_license.name).to eq(license_name)
      end
    end

    context 'when valid parameters are specified' do
      let(:params) { { name: license_name, approval_status: 'allowed' } }

      subject(:result) { described_class.new(project, user, params).execute }

      context 'when a software license is part of the spdx catalog' do
        let(:license_name) { 'MIT License' }
        let(:license_spdx_identifier) { 'MIT' }

        it 'does not call CustomSoftwareLicense::FindOrCreateService' do
          expect(Security::CustomSoftwareLicenses::FindOrCreateService).not_to receive(:new)

          result
        end

        it 'creates one software license policy correctly' do
          result

          expect(project.software_license_policies.count).to be(1)
          expect(result[:status]).to be(:success)
          expect(result[:software_license_policy]).to be_present
          expect(result[:software_license_policy]).to be_persisted
          expect(result[:software_license_policy].name).to eq(params[:name])
          expect(result[:software_license_policy].classification).to eq(params[:approval_status])
          expect(result[:software_license_policy].software_license_spdx_identifier).to eq(license_spdx_identifier)
        end
      end

      context 'when the software license is not part of the spdx catalog' do
        let(:license_name) { 'License outside spdx catalogue' }

        it 'calls CustomSoftwareLicense::FindOrCreateService' do
          expect_next_instance_of(Security::CustomSoftwareLicenses::FindOrCreateService, project: project,
            params: params) do |service|
            expect(service).to receive(:execute).and_call_original
          end

          result
        end

        it 'creates one software license policy correctly' do
          result
          expect(project.software_license_policies.count).to be(1)
          expect(result[:status]).to be(:success)
          expect(result[:software_license_policy]).to be_present
          expect(result[:software_license_policy]).to be_persisted
          expect(result[:software_license_policy].name).to eq(params[:name])
          expect(result[:software_license_policy].classification).to eq(params[:approval_status])
          expect(result[:software_license_policy].software_license_spdx_identifier).to be_nil
          expect(result[:software_license_policy].custom_software_license.name).to eq(license_name)
        end
      end
    end

    context 'when invalid input is provided' do
      before do
        params[:approval_status] = nil
      end

      specify { expect(service.execute[:status]).to be(:error) }
      specify { expect(service.execute[:message]).to be_present }
      specify { expect(service.execute[:http_status]).to be(400) }
    end
  end
end
