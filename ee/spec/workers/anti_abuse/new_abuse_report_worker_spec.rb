# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AntiAbuse::NewAbuseReportWorker, :saas, feature_category: :instance_resiliency do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:abuse_report) { create(:abuse_report, user: user, reporter: reporter) }
  let_it_be(:job_args) { [abuse_report.id] }

  shared_examples 'bans user' do
    it 'bans the user' do
      expect(user).not_to be_banned

      allow(Gitlab::AppLogger).to receive(:info)
      expect(Gitlab::AppLogger).to receive(:info).with(
        message: "User ban",
        user_id: user.id,
        username: user.username,
        abuse_report_id: abuse_report.id,
        reason: "Automatic ban triggered by abuse report for #{abuse_report.category}."
      )

      worker.perform(*job_args)

      expect(user).to be_banned
      expect(
        user.custom_attributes.by_key(UserCustomAttribute::AUTO_BANNED_BY_ABUSE_REPORT_ID).first.value
      ).to eq(abuse_report.id.to_s)
    end
  end

  shared_examples 'does not ban user' do
    it 'does not ban the user' do
      expect(user).not_to receive(:ban!)
      expect(UserCustomAttribute).not_to receive(:upsert_custom_attributes)
      worker.perform(*job_args)

      expect(user).not_to be_banned
    end
  end

  it_behaves_like 'an idempotent worker' do
    subject(:worker) { described_class.new }

    context 'when reporter is a gitlab employee' do
      before do
        allow(reporter).to receive(:gitlab_employee?).and_return(true)
        allow(user).to receive(:human?).and_return(true)
        allow(user).to receive(:active?).and_return(true)
        allow(AbuseReport).to receive(:find_by_id).and_return(abuse_report)
      end

      context 'when the user is a member of a namespace with a paid plan trial subscription' do
        let_it_be(:trial_group) do
          create(
            :group_with_plan,
            plan: :ultimate_plan,
            trial: true,
            trial_starts_on: Date.current,
            trial_ends_on: 1.day.from_now,
            reporters: user
          )
        end

        it_behaves_like 'bans user'
      end

      context 'when the user is a member of a namespace with a paid plan subscription' do
        let_it_be(:paid_group) { create(:group_with_plan, plan: :ultimate_plan, reporters: user) }

        it_behaves_like 'does not ban user'
      end

      context 'when the user is on a free plan' do
        context 'when the user is human' do
          it_behaves_like 'bans user'
        end

        context 'when the user is not human' do
          before do
            allow(user).to receive(:human?).and_return(false)
          end

          it_behaves_like 'does not ban user'
        end
      end

      context 'when the user is not active' do
        before do
          allow(user).to receive(:active?).and_return(false)
        end

        it_behaves_like 'does not ban user'
      end

      context 'when the user is not found' do
        before do
          allow(abuse_report).to receive(:user).and_return(nil)
        end

        it 'does not start a transaction' do
          expect(described_class).not_to receive(:bannable_user?)

          worker.perform(*job_args)
        end
      end

      context 'when the user is a gitlab employee' do
        before do
          allow(user).to receive(:gitlab_employee?).and_return(true)
        end

        it_behaves_like 'does not ban user'
      end

      context 'when the user age is greater than 7 days' do
        before do
          user.update_attribute(:created_at, 8.days.ago)
        end

        it_behaves_like 'does not ban user'
      end

      context 'when user owns namespaces with more than five members' do
        let_it_be(:group) { create(:group, owners: user, guests: create_list(:user, 5)) }

        it_behaves_like 'does not ban user'
      end
    end

    context 'when reporter is not a gitlab employee' do
      it_behaves_like 'does not ban user'
    end

    context 'when the abuse report is not found' do
      before do
        allow(AbuseReport).to receive(:find_by_id).and_return(nil)
      end

      it 'returns early' do
        expect(abuse_report).not_to receive(:reporter)

        worker.perform(*job_args)
      end
    end

    context 'when there is an error executing ban' do
      before do
        allow(user).to receive(:ban!).and_raise(StateMachines::InvalidTransition)
      end

      it 'does not emit an application log' do
        expect(Gitlab::AppLogger).not_to receive(:info)

        worker.perform(*job_args)
      end
    end
  end
end
