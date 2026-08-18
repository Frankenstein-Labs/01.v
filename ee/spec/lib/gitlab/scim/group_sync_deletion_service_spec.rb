# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Scim::GroupSyncDeletionService, feature_category: :system_access do
  let(:scim_group_uid) { SecureRandom.uuid }
  let(:service) { described_class.new(scim_group_uid: scim_group_uid) }

  describe '#execute' do
    let!(:saml_group_link) do
      create(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
    end

    it 'returns success' do
      result = service.execute

      expect(result).to be_success
    end

    it 'clears scim_group_uid from SAML group link' do
      expect { service.execute }.to change { saml_group_link.reload.scim_group_uid }.from(scim_group_uid).to(nil)
    end

    context 'with multiple group links' do
      let!(:another_group_link) do
        create(:saml_group_link, saml_group_name: 'engineering', scim_group_uid: scim_group_uid)
      end

      it 'clears scim_group_uid from all matching links' do
        service.execute

        expect(saml_group_link.reload.scim_group_uid).to be_nil
        expect(another_group_link.reload.scim_group_uid).to be_nil
      end
    end

    it 'schedules Authn::CleanupScimGroupMembershipsWorker' do
      expect(::Authn::CleanupScimGroupMembershipsWorker).to receive(:perform_async).with(scim_group_uid)

      service.execute
    end

    context 'when database error occurs' do
      before do
        allow(SamlGroupLink).to receive(:by_scim_group_uid).and_raise(ActiveRecord::ActiveRecordError, 'Database error')
      end

      it 'returns error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('Database error')
      end
    end
  end
end
