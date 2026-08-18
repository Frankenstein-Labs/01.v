# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::CleanupScimGroupMembershipsWorker, feature_category: :system_access do
  let(:worker) { described_class.new }
  let(:scim_group_uid) { SecureRandom.uuid }

  describe '#perform' do
    context 'with SCIM group memberships' do
      let!(:unrelated_membership) { create(:scim_group_membership, scim_group_uid: SecureRandom.uuid) }

      before do
        create(:scim_group_membership, scim_group_uid: scim_group_uid)
        create(:scim_group_membership, scim_group_uid: scim_group_uid)
      end

      it 'deletes all memberships for the specified SCIM group' do
        expect { worker.perform(scim_group_uid) }.to change { Authn::ScimGroupMembership.count }.by(-2)

        expect(Authn::ScimGroupMembership.where(scim_group_uid: scim_group_uid)).to be_empty
        expect(unrelated_membership.reload).to be_present
      end
    end

    context 'with blank scim_group_uid' do
      it 'returns early' do
        expect(Authn::ScimGroupMembership).not_to receive(:by_scim_group_uid)

        worker.perform('')
        worker.perform(nil)
      end
    end
  end
end
