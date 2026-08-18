# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::SeatAwareProvisioning, feature_category: :seat_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let(:current_date) { Date.current.iso8601 }

  let(:test_class) do
    Class.new do
      include GitlabSubscriptions::MemberManagement::SeatAwareProvisioning
    end
  end

  let(:instance) { test_class.new }

  shared_examples 'rescues and logs Redis error' do
    it 'rescues and logs Redis error' do
      allow(::Gitlab::Redis::SharedState).to receive(:with).and_raise(::Redis::BaseError)

      expect(::Gitlab::ErrorTracking).to receive(:log_exception).with(instance_of(::Redis::BaseError))

      expect { subject }.not_to raise_error
    end
  end

  shared_examples 'returns 0 on Redis error' do
    it 'returns 0' do
      allow(::Gitlab::Redis::SharedState).to receive(:with).and_raise(::Redis::BaseError)

      expect(subject).to eq(0)
    end
  end

  describe '.instance_affected_users_count', :clean_gitlab_redis_shared_state, :freeze_time do
    let(:redis_instance_key) { "seat_aware_provisioning:instance:{#{current_date}}" }

    subject(:affected_users_count) { described_class.instance_affected_users_count }

    before do
      ::Gitlab::Redis::SharedState.with do |redis|
        redis.sadd(redis_instance_key, %w[1 2 3])
      end
    end

    it 'returns the count of affected users' do
      expect(affected_users_count).to eq(3)
    end

    it_behaves_like 'rescues and logs Redis error'
    it_behaves_like 'returns 0 on Redis error'
  end

  describe '.record_instance_count_at_dismissal', :clean_gitlab_redis_shared_state, :freeze_time do
    let(:redis_instance_key) { "seat_aware_provisioning:instance:{#{current_date}}" }
    let(:dismissed_count_key) { "seat_aware_provisioning:instance:dismissed_count:#{user.id}:{#{current_date}}" }

    subject(:count_at_dismissal) { described_class.record_instance_count_at_dismissal(user) }

    before do
      ::Gitlab::Redis::SharedState.with do |redis|
        redis.sadd(redis_instance_key, %w[1 2 3])
      end
    end

    it 'records the current affected users count for the user' do
      count_at_dismissal

      ::Gitlab::Redis::SharedState.with do |redis|
        expect(redis.get(dismissed_count_key).to_i).to eq(3)
      end
    end

    it_behaves_like 'rescues and logs Redis error'
  end

  describe '.instance_count_at_last_dismissal', :clean_gitlab_redis_shared_state, :freeze_time do
    let(:dismissed_count_key) { "seat_aware_provisioning:instance:dismissed_count:#{user.id}:{#{current_date}}" }

    subject(:count_at_last_dismissal) { described_class.instance_count_at_last_dismissal(user) }

    before do
      ::Gitlab::Redis::SharedState.with do |redis|
        redis.set(dismissed_count_key, "3")
      end
    end

    it 'returns the stored dismissed count' do
      expect(count_at_last_dismissal).to eq(3)
    end

    context 'when the dismissal was recorded on a previous day' do
      let(:previous_date_key) do
        "seat_aware_provisioning:instance:dismissed_count:#{user.id}:{#{Date.yesterday.iso8601}}"
      end

      it 'returns 0' do
        ::Gitlab::Redis::SharedState.with do |redis|
          redis.del(dismissed_count_key)
          redis.set(previous_date_key, "3")
        end

        expect(count_at_last_dismissal).to eq(0)
      end
    end

    it_behaves_like 'rescues and logs Redis error'
    it_behaves_like 'returns 0 on Redis error'
  end

  describe '.group_affected_users_count', :clean_gitlab_redis_shared_state, :freeze_time do
    let(:redis_users_key) { "seat_aware_provisioning:group:#{group.id}:{#{current_date}}" }

    subject(:affected_users_count) { described_class.group_affected_users_count(group) }

    before do
      ::Gitlab::Redis::SharedState.with do |redis|
        redis.sadd(redis_users_key, %w[1 2 3])
      end
    end

    it 'returns the count of affected users for the group' do
      expect(affected_users_count).to eq(3)
    end

    it_behaves_like 'rescues and logs Redis error'
    it_behaves_like 'returns 0 on Redis error'
  end

  describe '.record_group_count_at_dismissal', :clean_gitlab_redis_shared_state, :freeze_time do
    let(:redis_users_key) { "seat_aware_provisioning:group:#{group.id}:{#{current_date}}" }
    let(:dismissed_count_key) do
      "seat_aware_provisioning:group:{#{group.id}}:dismissed_count:#{user.id}:#{current_date}"
    end

    subject(:count_at_dismissal) { described_class.record_group_count_at_dismissal(group, user) }

    before do
      ::Gitlab::Redis::SharedState.with do |redis|
        redis.sadd(redis_users_key, %w[1 2 3])
      end
    end

    it 'records the current affected users count for the group and user' do
      count_at_dismissal

      ::Gitlab::Redis::SharedState.with do |redis|
        expect(redis.get(dismissed_count_key).to_i).to eq(3)
      end
    end

    it_behaves_like 'rescues and logs Redis error'
  end

  describe '.group_count_at_last_dismissal', :clean_gitlab_redis_shared_state, :freeze_time do
    let(:dismissed_count_key) do
      "seat_aware_provisioning:group:{#{group.id}}:dismissed_count:#{user.id}:#{current_date}"
    end

    subject(:count_at_last_dismissal) { described_class.group_count_at_last_dismissal(group, user) }

    before do
      ::Gitlab::Redis::SharedState.with do |redis|
        redis.set(dismissed_count_key, "3")
      end
    end

    it 'returns the stored dismissed count' do
      expect(count_at_last_dismissal).to eq(3)
    end

    context 'when the dismissal was recorded on a previous day' do
      let(:previous_date_key) do
        "seat_aware_provisioning:group:{#{group.id}}:dismissed_count:#{user.id}:#{Date.yesterday.iso8601}"
      end

      it 'returns 0' do
        ::Gitlab::Redis::SharedState.with do |redis|
          redis.del(dismissed_count_key)
          redis.set(previous_date_key, "3")
        end

        expect(count_at_last_dismissal).to eq(0)
      end
    end

    it_behaves_like 'rescues and logs Redis error'
    it_behaves_like 'returns 0 on Redis error'
  end

  describe '#calculate_adjusted_access_level' do
    let(:desired_access) { Gitlab::Access::DEVELOPER }
    let(:invitee) { user }
    let(:expected_user_identifier) { user.id }
    let(:expected_user_id_in_log) { user.id }

    subject(:result) do
      instance.calculate_adjusted_access_level(group, invitee, desired_access)
    end

    before do
      allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
        .to receive(:block_seat_overages?).with(group).and_return(true)
      allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
        .to receive(:seats_available_for?)
    end

    shared_examples 'feature flag disabled behavior' do
      it 'returns desired access level unchanged' do
        expect(result.access_level).to eq(desired_access)
        expect(result.adjusted?).to be false
        expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .not_to have_received(:seats_available_for?)
      end
    end

    shared_examples 'seats available behavior' do
      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?).and_return(true)
      end

      it 'returns desired access level' do
        expect(result.access_level).to eq(desired_access)
        expect(result.adjusted?).to be false
        expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to have_received(:seats_available_for?)
          .with(group, [expected_user_identifier], desired_access, nil)
      end

      it 'does not log access level adjustment' do
        allow(Gitlab::AppLogger).to receive(:info)

        result

        expect(Gitlab::AppLogger).not_to have_received(:info).with(
          hash_including(message: 'Group membership access level adjusted due to BSO seat limits')
        )
      end
    end

    shared_examples 'seats not available behavior' do
      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?).and_return(false)
      end

      it 'returns minimal access' do
        expect(result.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
        expect(result.adjusted?).to be true
        expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to have_received(:seats_available_for?)
          .with(group, [expected_user_identifier], desired_access, nil)
      end

      it 'logs the access level adjustment' do
        allow(Gitlab::AppLogger).to receive(:info)

        result

        expect(Gitlab::AppLogger).to have_received(:info).with(
          hash_including(
            message: 'Group membership access level adjusted due to BSO seat limits',
            group_id: group.id,
            group_path: group.full_path,
            user_id: expected_user_id_in_log,
            requested_access_level: desired_access,
            adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
            feature_flag: 'bso_minimal_access_fallback'
          )
        )
      end

      it 'logs the access level adjustment with extra parameters' do
        allow(Gitlab::AppLogger).to receive(:info)

        instance.calculate_adjusted_access_level(group, user, desired_access, { scim_group_uid: 'test-uid' })

        expect(Gitlab::AppLogger).to have_received(:info).with(
          hash_including(scim_group_uid: 'test-uid')
        )
      end
    end

    shared_examples 'BSO feature flag enabled behavior' do
      context 'when seats are available' do
        include_examples 'seats available behavior'
      end

      context 'when seats are not available' do
        include_examples 'seats not available behavior'
      end
    end

    context 'when on SaaS', :saas do
      context 'when bso_minimal_access_fallback feature flag is disabled for the group' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: false)
        end

        include_examples 'feature flag disabled behavior'
      end

      context 'when bso_minimal_access_fallback feature flag is enabled for the group' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: group.root_ancestor)
        end

        include_examples 'BSO feature flag enabled behavior'
      end
    end

    context 'when on self-managed' do
      context 'when bso_minimal_access_fallback feature flag is disabled instance-wide' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: false)
        end

        include_examples 'feature flag disabled behavior'
      end

      context 'when bso_minimal_access_fallback feature flag is enabled instance-wide' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: true)
        end

        include_examples 'BSO feature flag enabled behavior'
      end
    end

    context 'when BSO is not enabled' do
      before do
        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:block_seat_overages?).with(group).and_return(false)
      end

      it 'returns desired access level unchanged' do
        expect(result.access_level).to eq(desired_access)
        expect(result.adjusted?).to be false
        expect(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .not_to have_received(:seats_available_for?)
      end
    end
  end

  describe '#track_and_audit_minimal_access_provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
    let!(:member) { create(:group_member, group: group, user: user) }
    let(:desired_access) { Gitlab::Access::DEVELOPER }
    let(:invitee) { member }
    let(:redis_instance_key) { "seat_aware_provisioning:instance:{#{current_date}}" }

    subject(:track_and_audit) { instance.track_and_audit_minimal_access_provisioning(group, invitee, desired_access) }

    context 'when bso_minimal_access_fallback feature flag is disabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: false)
      end

      it 'does not audit event' do
        track_and_audit

        expect(AuditEventReader.count).to eq(0)
      end

      it 'does not write to cache' do
        track_and_audit

        ::Gitlab::Redis::SharedState.with do |redis|
          expect(redis.exists?(redis_instance_key)).to be false
        end
      end
    end

    context 'when bso_minimal_access_fallback feature flag is enabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: true)
      end

      context 'when member is nil' do
        let(:invitee) { nil }

        it 'does not audit event' do
          track_and_audit

          expect(AuditEventReader.count).to eq(0)
        end

        it 'does not write to cache' do
          track_and_audit

          ::Gitlab::Redis::SharedState.with do |redis|
            expect(redis.exists?(redis_instance_key)).to be false
          end
        end
      end

      describe '#audit_minimal_access_role_adjustment' do
        it 'audits event', :aggregate_failures do
          track_and_audit

          event = AuditEventReader.last
          expect(event.author.name).to eq('(System)')
          expect(event.entity).to eq(group)
          expect(event.target_id).to eq(user.id)
          expect(event.details[:custom_message]).to eq(
            'Assigned Minimal Access due to seat limit with restricted access.'
          )
          expect(event.details[:member_id]).to eq(invitee.id)
          expect(event.details[:user_id]).to eq(user.id)
          expect(event.details[:requested_access_level]).to eq(::Gitlab::Access::DEVELOPER)
          expect(event.details[:event_name]).to eq('group_minimal_access_role_adjusted_seat_limit')
        end

        it 'audits event with extra parameters' do
          instance.track_and_audit_minimal_access_provisioning(
            group, invitee, desired_access, { scim_group_uid: 'test-uid' }
          )

          event = AuditEventReader.last
          expect(event.details[:scim_group_uid]).to eq('test-uid')
        end
      end

      describe '#track_minimal_access_provisioning' do
        let(:root_namespace) { group }
        let(:user_identifier) { member.user_id }
        let(:redis_root_groups_key) { "seat_aware_provisioning:group:{#{current_date}}" }
        let(:redis_users_key) { "seat_aware_provisioning:group:#{root_namespace.id}:{#{current_date}}" }

        context 'when on self-managed' do
          it 'writes to instance scoped cache' do
            track_and_audit

            ::Gitlab::Redis::SharedState.with do |redis|
              expect(redis.sismember(redis_instance_key, user_identifier.to_s)).to be true
            end
          end

          it 'sets a TTL to instance scoped cache' do
            track_and_audit

            ::Gitlab::Redis::SharedState.with do |redis|
              expect(redis.ttl(redis_instance_key)).to be_within(1.second).of(72.hours)
            end
          end

          it 'does not write to namespace scoped caches' do
            track_and_audit

            ::Gitlab::Redis::SharedState.with do |redis|
              expect(redis.sismember(redis_root_groups_key, group.id.to_s)).to be false
              expect(redis.sismember(redis_users_key, user_identifier.to_s)).to be false
            end
          end

          it_behaves_like 'rescues and logs Redis error'
        end

        context 'when on SaaS', :saas do
          it 'writes to namespace scoped caches' do
            track_and_audit

            ::Gitlab::Redis::SharedState.with do |redis|
              expect(redis.sismember(redis_root_groups_key, group.id.to_s)).to be true
              expect(redis.sismember(redis_users_key, user_identifier.to_s)).to be true
            end
          end

          it 'sets a TTL to namespace scoped caches' do
            track_and_audit

            ::Gitlab::Redis::SharedState.with do |redis|
              expect(redis.ttl(redis_root_groups_key)).to be_within(1.second).of(72.hours)
              expect(redis.ttl(redis_users_key)).to be_within(1.second).of(72.hours)
            end
          end

          it 'does not write to instance scoped cache' do
            track_and_audit

            ::Gitlab::Redis::SharedState.with do |redis|
              expect(redis.sismember(redis_instance_key, user_identifier.to_s)).to be false
            end
          end

          it_behaves_like 'rescues and logs Redis error'
        end
      end
    end
  end
end
