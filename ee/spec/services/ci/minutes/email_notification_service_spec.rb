# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::EmailNotificationService, feature_category: :hosted_runners do
  include ::Ci::MinutesHelpers

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.new(project).execute }

    where(:monthly_minutes_limit, :minutes_used, :minutes_left, :percent_left, :current_notification_level,
      :new_notification_level, :result) do
      1000 | 500  | 500 | 50 | 100 | 100 | [false]
      1000 | 800  | 200 | 20 | 100 | 25  | [true, 25]
      1000 | 800  | 200 | 20 | 25  | 25  | [false]
      1000 | 950  |  50 |  5 | 100 | 5   | [true, 5]
      1000 | 950  |  50 |  5 | 30  | 5   | [true, 5]
      1000 | 950  |  50 |  5 | 5   | 5   | [false]
      1000 | 1000 |   0 |  0 | 100 | 0   | [true, 0]
      1000 | 1000 |   0 |  0 | 25  | 0   | [true, 0]
      1000 | 1000 |   0 |  0 | 5   | 0   | [true, 0]
      1000 | 1001 |   0 |  0 | 5   | 0   | [true, 0]
      1000 | 1000 |   0 |  0 | 0   | 0   | [false]
      0    | 1000 |   0 |  0 | 100 | 100 | [false]
    end

    with_them do
      shared_examples 'sends the expected email' do
        it 'matches the expectation on the email sent' do
          email_sent, level_notified = result

          if email_sent
            if level_notified > 0
              expect(CiMinutesUsageMailer)
                .to receive(:notify_limit)
                .with(namespace, match_array(recipients),
                  minutes_left, monthly_minutes_limit, percent_left, level_notified)
                .and_call_original
            else
              expect(CiMinutesUsageMailer)
                .to receive(:notify)
                .with(namespace, match_array(recipients))
                .and_call_original
            end
          else
            expect(CiMinutesUsageMailer).not_to receive(:notify_limit)
            expect(CiMinutesUsageMailer).not_to receive(:notify)
          end

          subject
        end
      end

      shared_examples 'updates the notification level' do
        it 'matches the updated notification level' do
          subject

          expect(namespace_usage.reload.notification_level).to eq(new_notification_level)
        end
      end

      shared_examples 'matches the expectations' do
        it_behaves_like 'sends the expected email'
        it_behaves_like 'updates the notification level'
      end

      shared_examples 'notifies namespace owners of compute usage' do
        it_behaves_like 'matches the expectations'

        context 'when there are multiple shards' do
          let!(:other_shard_usage) do
            create(:ci_namespace_monthly_usage, namespace: namespace, shard_number: 2, amount_used: 0)
          end

          it_behaves_like 'sends the expected email'
        end
      end

      let_it_be(:user) { create(:user) }
      let_it_be(:user_2) { create(:user) }

      let(:project) { create(:project, namespace: namespace) }

      let(:namespace_usage) do
        Ci::Minutes::NamespaceMonthlyUsage.find_or_create_current(namespace_id: namespace.id)
      end

      before do
        namespace_usage.update!(amount_used: minutes_used, notification_level: current_notification_level)
        namespace.update_column(:shared_runners_minutes_limit, monthly_minutes_limit)
      end

      context 'when on personal namespace' do
        let(:namespace) { create(:namespace, owner: user) }
        let(:recipients) { [user.email] }

        it_behaves_like 'notifies namespace owners of compute usage'
      end

      context 'when on group' do
        let(:namespace) { create(:group) }
        let(:recipients) { [user.email, user_2.email] }

        before do
          namespace.add_owner(user)
          namespace.add_owner(user_2)
        end

        it_behaves_like 'notifies namespace owners of compute usage'
      end
    end

    context 'when another shard has already been notified at the threshold' do
      let_it_be(:user) { create(:user) }

      let(:namespace) { create(:namespace, owner: user) }
      let(:project) { create(:project, namespace: namespace) }

      where(:minutes_used, :notified_level) do
        800  | 25
        950  | 5
        1000 | 0
      end

      with_them do
        before do
          namespace.update_column(:shared_runners_minutes_limit, 1000)

          Ci::Minutes::NamespaceMonthlyUsage.find_or_create_current(namespace_id: namespace.id)
            .update!(amount_used: minutes_used, notification_level: 100)

          create(:ci_namespace_monthly_usage, namespace: namespace, shard_number: 2,
            amount_used: 0, notification_level: notified_level)
        end

        it 'does not send another email' do
          expect(CiMinutesUsageMailer).not_to receive(:notify_limit)
          expect(CiMinutesUsageMailer).not_to receive(:notify)

          described_class.new(project).execute
        end
      end
    end
  end
end
