# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Minutes::Notification, feature_category: :hosted_runners do
  include ::Ci::MinutesHelpers

  let_it_be(:user) { create(:user) }
  let(:shared_runners_enabled) { true }
  let!(:project) { create(:project, :small_repo, namespace: group, shared_runners_enabled: shared_runners_enabled) }
  let_it_be_with_refind(:group) { create(:group) }

  let(:injected_group) { group }
  let(:injected_project) { project }

  shared_examples 'queries for notifications' do
    context 'without limit' do
      it { is_expected.to be false }
    end

    context 'when limit is defined' do
      context 'when limit not yet exceeded' do
        let(:group) { create(:group, :with_not_used_build_minutes_limit) }

        it { is_expected.to be false }
      end

      context 'when minutes are not yet set' do
        let(:group) { create(:group, :with_ci_minutes, ci_minutes_limit: nil) }

        it { is_expected.to be false }
      end
    end
  end

  shared_examples 'has notifications' do
    shared_examples 'dismissible alert' do |stage|
      let_it_be(:feature_id) { "ci_minutes_limit_alert_#{stage}_stage" }

      context 'when the user dismissed the alert under 30 days ago', :freeze_time do
        before do
          allow_dismissal true
        end

        it 'does not render the alert' do
          expect(subject.show_callout?(user)).to be false
        end
      end

      context 'when the user dismissed the alert over 30 days ago', :freeze_time do
        before do
          allow_dismissal false
        end

        it 'renders the alert' do
          expect(subject.show_callout?(user)).to be true
        end
      end

      def allow_dismissal(is_allowed)
        if injected_group.user_namespace?
          allow(user).to receive(:dismissed_callout?).with(
            feature_name: feature_id,
            ignore_dismissal_earlier_than: 30.days.ago
          ).and_return(is_allowed)
        else
          allow(user).to receive(:dismissed_callout_for_group?).with(
            feature_name: feature_id,
            group: injected_group,
            ignore_dismissal_earlier_than: 30.days.ago
          ).and_return(is_allowed)
        end
      end
    end

    context 'when usage has reached a notification level' do
      before do
        group.shared_runners_minutes_limit = 20
      end

      context 'when at the warning level' do
        before do
          set_ci_minutes_used(group, 16)
        end

        describe '#show_callout?' do
          it 'has warning notification' do
            expect(subject.show_callout?(user)).to be true
          end

          it_behaves_like 'dismissible alert', :warning
        end

        describe '#running_out?' do
          it 'is running out of minutes' do
            expect(subject.running_out?).to be true
          end
        end

        describe '#no_remaining_minutes?' do
          it 'has not ran out of minutes' do
            expect(subject.no_remaining_minutes?).to be false
          end
        end

        describe '#stage_percentage' do
          it 'provides percentage for current alert level' do
            expect(subject.stage_percentage).to eq 25
          end
        end
      end

      context 'when at the danger level' do
        before do
          set_ci_minutes_used(group, 19)
        end

        describe '#show_callout?' do
          it 'has danger notification' do
            expect(subject.show_callout?(user)).to be true
          end

          it_behaves_like 'dismissible alert', :danger
        end

        describe '#running_out?' do
          it 'is running out of minutes' do
            expect(subject.running_out?).to be true
          end
        end

        describe '#no_remaining_minutes?' do
          it 'has not ran out of minutes' do
            expect(subject.no_remaining_minutes?).to be false
          end
        end

        describe '#stage_percentage' do
          it 'provides percentage for current alert level' do
            expect(subject.stage_percentage).to eq 5
          end
        end
      end

      context 'when just before the limit enforcement' do
        before do
          group.shared_runners_minutes_limit = 1_000
          set_ci_minutes_used(group, 999)
        end

        describe '#show_callout?' do
          it 'has warning notification' do
            expect(subject.show_callout?(user)).to be true
          end

          it_behaves_like 'dismissible alert', :danger
        end

        describe '#running_out?' do
          it 'is running out of minutes' do
            expect(subject.running_out?).to be true
          end
        end

        describe '#no_remaining_minutes?' do
          it 'has not ran out of minutes' do
            expect(subject.no_remaining_minutes?).to be false
          end
        end

        describe '#stage_percentage' do
          it 'provides percentage for current alert level' do
            expect(subject.stage_percentage).to eq 5
          end
        end
      end

      context 'when usage has reached the limit' do
        before do
          set_ci_minutes_used(group, 20)
        end

        describe '#show_callout?' do
          it 'has exceeded notification' do
            expect(subject.show_callout?(user)).to be true
          end

          it_behaves_like 'dismissible alert', :exceeded
        end

        describe '#running_out?' do
          it 'does not have any minutes left' do
            expect(subject.running_out?).to be false
          end
        end

        describe '#no_remaining_minutes?' do
          it 'has run out of minutes out of minutes' do
            expect(subject.no_remaining_minutes?).to be true
          end
        end

        describe '#stage_percentage' do
          it 'provides percentage for current alert level' do
            expect(subject.stage_percentage).to eq 0
          end
        end
      end
    end
  end

  shared_examples 'not eligible to see notifications' do
    before do
      group.shared_runners_minutes_limit = 10
      set_ci_minutes_used(group, 8)
    end

    context 'when not permitted to see notifications' do
      describe '#show_callout?' do
        it 'has no notifications set' do
          expect(subject.show_callout?(user)).to be false
        end
      end
    end
  end

  context 'when in a project' do
    context 'when eligible to see notifications' do
      before_all do
        group.add_owner(user)
      end

      describe '#show_callout?' do
        it_behaves_like 'queries for notifications' do
          subject do
            threshold = described_class.new(injected_project, nil)
            threshold.show_callout?(user)
          end
        end
      end

      it_behaves_like 'has notifications' do
        subject { described_class.new(injected_project, nil) }
      end
    end

    it_behaves_like 'not eligible to see notifications' do
      subject { described_class.new(injected_project, nil) }
    end

    context 'when user is not authenticated' do
      let(:user) { nil }

      it_behaves_like 'not eligible to see notifications' do
        subject { described_class.new(injected_project, nil) }
      end
    end

    context 'when user is not in the correct role' do
      before_all do
        group.add_developer user
      end

      it_behaves_like 'not eligible to see notifications' do
        subject { described_class.new(injected_project, nil) }
      end
    end
  end

  context 'when in a group' do
    context 'when eligible to see notifications' do
      before_all do
        group.add_owner(user)
      end

      context 'with a project that has runners enabled inside namespace' do
        describe '#show_callout?' do
          it_behaves_like 'queries for notifications' do
            subject do
              threshold = described_class.new(nil, injected_group)
              threshold.show_callout?(user)
            end
          end
        end

        it_behaves_like 'has notifications' do
          subject { described_class.new(nil, injected_group) }
        end
      end

      context 'with no projects that have runners enabled inside namespace' do
        it_behaves_like 'not eligible to see notifications' do
          let(:shared_runners_enabled) { false }
          subject { described_class.new(nil, injected_group) }
        end
      end
    end

    it_behaves_like 'not eligible to see notifications' do
      subject { described_class.new(nil, injected_group) }
    end

    context 'when user is not authenticated' do
      let(:user) { nil }

      it_behaves_like 'not eligible to see notifications' do
        subject { described_class.new(injected_project, nil) }
      end
    end

    context 'when user is not in the correct role' do
      before_all do
        group.add_developer user
      end

      it_behaves_like 'not eligible to see notifications' do
        subject { described_class.new(injected_project, nil) }
      end
    end
  end

  context 'when in a user namespace' do
    let_it_be_with_refind(:group) { create(:user_namespace, name: 'user_namespace') }
    let_it_be(:user) { create(:user, namespace: group) }

    it_behaves_like 'has notifications' do
      subject { described_class.new(nil, injected_group) }
    end
  end
end
