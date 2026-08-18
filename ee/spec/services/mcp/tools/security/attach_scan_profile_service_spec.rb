# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Security::AttachScanProfileService, feature_category: :mcp_server do
  let(:service) { described_class.new(name: 'attachScanProfile') }

  describe '.available_versions' do
    subject { described_class.available_versions }

    it { is_expected.to contain_exactly('0.1.0') }
  end

  describe '#annotations' do
    subject { service.annotations }

    it { is_expected.to eq({ readOnlyHint: false, destructiveHint: false }) }
  end

  describe 'input schema' do
    let(:schema) { described_class.version_metadata('0.1.0')[:input_schema] }

    it 'defines object type schema' do
      expect(schema[:type]).to eq('object')
    end

    it 'requires `security_scan_profile_id`' do
      expect(schema[:required]).to eq(['security_scan_profile_id'])
    end

    describe 'properties' do
      using RSpec::Parameterized::TableSyntax

      let(:properties) { schema[:properties] }

      where(:property_name, :expected_property_type) do
        :security_scan_profile_id | 'string'
        :project_ids              | 'array'
        :group_ids                | 'array'
      end

      with_them do
        let(:property_type) { properties.dig(property_name, :type) }

        it 'defines property with correct type and description' do
          expect(property_type).to eq(expected_property_type)
        end
      end
    end
  end

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:scan_profile) { create(:security_scan_profile, namespace: group) }

    let(:request) { instance_double(ActionDispatch::Request) }

    subject(:attach_profile) { service.execute(request: request, params: params) }

    before_all do
      group.add_maintainer(user)
    end

    before do
      service.set_cred(current_user: user)

      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when only project IDs provided' do
      let(:params) do
        {
          arguments: {
            security_scan_profile_id: scan_profile.to_global_id.to_s,
            project_ids: [project.to_global_id.to_s]
          }
        }
      end

      it 'attaches the given profile to given project' do
        expect { attach_profile }.to change { project.reload.security_scan_profiles.to_a }.to([scan_profile])
      end
    end

    context 'when only group IDs provided' do
      let(:params) do
        {
          arguments: {
            security_scan_profile_id: scan_profile.to_global_id.to_s,
            group_ids: [group.to_global_id.to_s]
          }
        }
      end

      before do
        allow(Security::ScanProfiles::AttachWorker).to receive(:bulk_perform_async_with_contexts)
      end

      it 'schedules attaching scan profile to the entire group' do
        attach_profile

        expect(Security::ScanProfiles::AttachWorker)
          .to have_received(:bulk_perform_async_with_contexts)
                .with([group], arguments_proc: an_instance_of(Proc), context_proc: an_instance_of(Proc))
      end
    end

    context 'when both project IDs and group IDs provided' do
      let(:params) do
        {
          arguments: {
            security_scan_profile_id: scan_profile.to_global_id.to_s,
            project_ids: [project.to_global_id.to_s],
            group_ids: [group.to_global_id.to_s]
          }
        }
      end

      before do
        allow(Security::ScanProfiles::AttachWorker).to receive(:bulk_perform_async_with_contexts)
      end

      it 'schedules attaching scan profile to the entire group' do
        attach_profile

        expect(Security::ScanProfiles::AttachWorker)
          .to have_received(:bulk_perform_async_with_contexts)
                .with([group], arguments_proc: an_instance_of(Proc), context_proc: an_instance_of(Proc))
      end

      it 'attaches the given profile to given project' do
        expect { attach_profile }.to change { project.reload.security_scan_profiles.to_a }.to([scan_profile])
      end
    end
  end
end
