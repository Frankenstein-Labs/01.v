# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Scim::Group::ReprovisioningService, feature_category: :system_access do
  describe '#execute' do
    let_it_be(:identity, freeze: false) { create(:scim_identity, active: false) }
    let_it_be(:group) { identity.group }
    let_it_be(:user) { identity.user }
    let_it_be(:saml_provider) do
      create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER)
    end

    let(:service) { described_class.new(identity) }

    it 'activates scim identity' do
      service.execute

      expect(identity.active).to be true
    end

    it 'creates the member' do
      service.execute

      expect(group.members.pluck(:user_id)).to include(user.id)
    end

    it 'creates the member with the access level as specified in saml_provider' do
      service.execute

      access_level = group.member(user).access_level

      expect(access_level).to eq(Gitlab::Access::DEVELOPER)
    end

    context 'when a custom role is given for created group member', feature_category: :permissions do
      let(:member_role) { create(:member_role, namespace: group) }
      let!(:saml_provider) do
        create(:saml_provider, group: group,
          default_membership_role: member_role.base_access_level,
          member_role: member_role)
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'sets the `member_role` of the member as specified in `saml_provider`' do
        service.execute

        expect(group.member(user).member_role).to eq(member_role)
      end
    end

    it 'does not change group membership when the user is already a member' do
      create(:group_member, group: group, user: user)

      expect { service.execute }.not_to change { group.members.count }
    end

    context 'with minimal access user' do
      before do
        stub_licensed_features(minimal_access_role: true)
        create(:group_member, group: group, user: user, access_level: ::Gitlab::Access::MINIMAL_ACCESS)
      end

      it 'does not change group membership when the user is already a member' do
        expect { service.execute }.not_to change { group.all_group_members.count }
      end
    end

    context 'with BSO (Block Seat Overages) enabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: true)
        stub_licensed_features(minimal_access_role: true)
      end

      context 'without available seats' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive_messages(
              block_seat_overages?: true,
              seats_available_for?: false
            )
        end

        it 'creates user with MINIMAL_ACCESS instead of the desired access level' do
          service.execute

          member = group.all_group_members.find_by(user: user)
          expect(member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
        end

        it 'logs BSO adjustment when access level is downgraded' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'Group membership access level adjusted due to BSO seat limits',
              group_id: group.id,
              group_path: group.full_path,
              user_id: user.id,
              requested_access_level: Gitlab::Access::DEVELOPER,
              adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
              feature_flag: 'bso_minimal_access_fallback'
            )
          )

          service.execute
        end

        it 'tracks minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
          service.execute

          ::Gitlab::Redis::SharedState.with do |redis|
            instance_key = "seat_aware_provisioning:instance:{#{Date.current.iso8601}}"
            expect(redis.sismember(instance_key, user.id.to_s)).to be true
          end
        end

        it 'audits minimal access role adjustment' do
          service.execute

          audit_event = AuditEventReader.find_by(target_id: user.id)

          expect(audit_event.entity).to eq(group)
          expect(audit_event.details[:user_id]).to eq(user.id)
          expect(audit_event.details[:requested_access_level]).to eq(Gitlab::Access::DEVELOPER)
          expect(audit_event.details[:scim_identity_id]).to eq(identity.id)
        end
      end

      context 'with available seats' do
        before do
          allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
            .to receive_messages(
              block_seat_overages?: true,
              seats_available_for?: true
            )
        end

        it 'creates user with the original desired access level' do
          service.execute

          member = group.all_group_members.find_by(user: user)
          expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
        end

        it 'does not log BSO adjustment' do
          expect(Gitlab::AppLogger).not_to receive(:info).with(
            hash_including(message: 'Group membership access level adjusted due to BSO seat limits')
          )

          service.execute
        end

        it 'does not track minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
          service.execute

          ::Gitlab::Redis::SharedState.with do |redis|
            instance_key = "seat_aware_provisioning:instance:{#{Date.current.iso8601}}"
            expect(redis.sismember(instance_key, user.id.to_s)).to be false
          end
        end
      end
    end
  end
end
