# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Import::SourceUser, feature_category: :importers do
  describe 'state machine' do
    context 'when switching to reassignment_in_progress without reassigned to user approval' do
      let_it_be(:reassign_to_user) { create(:user) }
      let_it_be(:group) { create(:group) }
      let_it_be(:owner) { create(:user) }

      subject(:source_user) { create(:import_source_user, :pending_reassignment, namespace: group) }

      before do
        source_user.reassign_to_user = reassign_to_user
        source_user.reassigned_by_user = owner
      end

      context 'when enterprise bypass placeholder user confirmation is allowed' do
        before do
          expect_next_instance_of(Import::UserMapping::EnterpriseBypassAuthorizer, group,
            reassign_to_user, owner) do |authorizer|
            allow(authorizer).to receive(:allowed?).and_return(true)
          end
        end

        it 'allows the transition' do
          expect(source_user.reassign_without_confirmation).to be(true)
        end
      end

      context 'when enterprise bypass placeholder user confirmation is not allowed' do
        before do
          expect_next_instance_of(Import::UserMapping::EnterpriseBypassAuthorizer, group,
            reassign_to_user, owner) do |authorizer|
            allow(authorizer).to receive(:allowed?).and_return(false)
          end
        end

        it 'does not allow the transition' do
          expect(source_user.reassign_without_confirmation).to be(false)
        end
      end

      context 'when service account bypass is allowed' do
        before do
          expect_next_instance_of(Import::UserMapping::ServiceAccountBypassAuthorizer, group,
            reassign_to_user, owner) do |authorizer|
            allow(authorizer).to receive(:allowed?).and_return(true)
          end
        end

        it 'allows the transition' do
          expect(source_user.reassign_without_confirmation).to be(true)
        end

        it 'changes to reassignment_in_progress' do
          expect { source_user.reassign_without_confirmation }.to change { source_user.status }.from(0).to(2)
        end
      end

      context 'when service account bypass is not allowed' do
        before do
          expect_next_instance_of(Import::UserMapping::ServiceAccountBypassAuthorizer, group,
            reassign_to_user, owner) do |authorizer|
            allow(authorizer).to receive(:allowed?).and_return(false)
          end
        end

        it 'does not allow the transition' do
          expect(source_user.reassign_without_confirmation).to be(false)
        end
      end
    end
  end
end
