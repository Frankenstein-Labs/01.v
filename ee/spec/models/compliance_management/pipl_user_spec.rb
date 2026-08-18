# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::PiplUser,
  feature_category: :compliance_management do
  it { is_expected.to belong_to(:user).required(true) }

  it { is_expected.to validate_presence_of(:last_access_from_pipl_country_at) }

  describe "scopes" do
    describe '.days_from_initial_pipl_email', time_travel_to: '2024-10-07 10:32:45.000000' do
      subject(:scope) { described_class.days_from_initial_pipl_email(*days) }

      # time_travel_to doesn't work with before_all and didn't want to use before to
      # avoid bad performance
      let!(:pipl_users) do
        create(:pipl_user, initial_email_sent_at: Time.current)
        create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
        create(:pipl_user, initial_email_sent_at: Time.current - 90.days)
      end

      let(:days) { [0.days, 30.days, 90.days] }

      it 'returns all the user_details' do
        result = scope

        expect(result.count).to eq(3)
      end

      context 'when days matches only a part of the details' do
        let(:days) { [30.days] }

        it 'returns only the matched results' do
          result = scope
          expect(result.count).to eq(1)
          expect(result.first.initial_email_sent_at).to eq(Time.current - 30.days)
        end
      end

      context 'when days does not match any records' do
        let(:days) { [10.days] }

        it 'does not return any results' do
          result = scope

          expect(result.count).to eq(0)
        end
      end
    end

    describe 'state' do
      it 'is set to 0 by default' do
        pipl_user = described_class.new

        expect(pipl_user.state).to eq("default")
      end

      it { is_expected.to define_enum_for(:state).with_values(default: 0) }
    end

    describe '.with_due_notifications', time_travel_to: '2024-10-07 10:32:45.000000' do
      subject(:scope) { described_class.with_due_notifications }

      context 'when all the users match a due date' do
        # time_travel_to doesn't work with before_all and didn't want to use before to
        # avoid bad performance
        let!(:pipl_users) do
          create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
          create(:pipl_user, initial_email_sent_at: Time.current - 53.days)
          create(:pipl_user, initial_email_sent_at: Time.current - 59.days)
        end

        it 'returns all the user_details' do
          result = scope

          expect(result.count).to eq(3)
        end
      end

      context 'when some users match a due date' do
        let!(:pipl_users) do
          create(:pipl_user, initial_email_sent_at: Time.current)
          create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
        end

        it 'returns only the matched results' do
          result = scope
          expect(result.count).to eq(1)
          expect(result.first.initial_email_sent_at).to eq(Time.current - 30.days)
        end
      end

      context 'when days does not match any records' do
        let!(:pipl_users) do
          create(:pipl_user, initial_email_sent_at: Time.current)
        end

        it 'does not return any results' do
          result = scope

          expect(result.count).to eq(0)
        end
      end
    end

    describe '.pipl_email_sent_on_or_before', time_travel_to: '2024-10-07 10:32:45.000000' do
      subject(:scope) { described_class.pipl_email_sent_on_or_before(date) }

      # time_travel_to doesn't work with before_all and didn't want to use before to
      # avoid bad performance
      let!(:pipl_users) do
        create(:pipl_user, initial_email_sent_at: Time.current)
        create(:pipl_user, initial_email_sent_at: Time.current - 30.days)
      end

      let(:date) { Time.current }

      it 'returns all the user_details' do
        result = scope

        expect(result.count).to eq(2)
      end

      context 'when date matches only a part of the details' do
        let(:date) { 30.days.ago }

        it 'returns only the matched results' do
          result = scope
          expect(result.count).to eq(1)
          expect(result.first.initial_email_sent_at).to eq(30.days.ago)
        end
      end

      context 'when date does not match any records' do
        let(:date) { 31.days.ago }

        it 'does not return any results' do
          result = scope

          expect(result.count).to eq(0)
        end
      end
    end

    describe '.pipl_blockable', time_travel_to: '2024-10-07 10:32:45.000000' do
      subject(:pipl_blockable) { described_class.pipl_blockable }

      let_it_be(:blocked_user) { create(:user, :blocked) }

      # time_travel_to doesn't work with before_all and didn't want to use before to
      # avoid bad performance
      let!(:pipl_users) do
        create(:pipl_user, initial_email_sent_at: 59.days.ago.beginning_of_day)
        create(:pipl_user, initial_email_sent_at: 60.days.ago.end_of_day)
        create(:pipl_user, initial_email_sent_at: 61.days.ago)
      end

      let(:threshold) { described_class::NOTICE_PERIOD.ago.end_of_day }

      it 'returns the threshold matching user_details' do
        result = pipl_blockable

        expect(result.count).to eq(2)

        result.each do |pipl_user|
          expect { pipl_user.user }.to match_query_count(0)
          expect(pipl_user.user.state).not_to eq(::User.state_machine.states[:blocked].value)
          expect(pipl_user.initial_email_sent_at <= threshold)
            .to be(true)
        end
      end

      context 'when there is a threshold-matching blocked user' do
        let(:other_user) { create(:pipl_user, initial_email_sent_at: threshold, user: blocked_user) }

        it "doesn't fetch the already-blocked user" do
          result = pipl_blockable

          expect(result.map(&:id)).to not_include(other_user.id)
        end
      end
    end
  end

  describe '.pipl_deletable', time_travel_to: '2024-10-07 10:32:45.000000' do
    subject(:pipl_deletable) { described_class.pipl_deletable }

    let_it_be(:blocked_user) { create(:user, :blocked) }

    # time_travel_to doesn't work with before_all and didn't want to use before to
    # avoid bad performance
    let!(:pipl_users) do
      create(:pipl_user, initial_email_sent_at: 59.days.ago.beginning_of_day)
      create(:pipl_user, initial_email_sent_at: 60.days.ago.end_of_day)
      create(:pipl_user, :deletable)
    end

    let(:threshold) { described_class::DELETION_PERIOD.ago.end_of_day }

    it 'returns the threshold matching pipl_users' do
      result = pipl_deletable

      expect(result.count).to eq(1)

      result.each do |pipl_user|
        expect { pipl_user.user }.to match_query_count(0)
        expect(pipl_user.user.state).to eq(::User.state_machine.states[:blocked].value)
        expect(pipl_user.initial_email_sent_at <= threshold)
          .to be(true)
      end
    end

    context 'when there is a threshold-matching non-blocked user' do
      let!(:other_user) { create(:pipl_user, initial_email_sent_at: threshold) }

      it "doesn't fetch the non-blocked user" do
        result = pipl_deletable

        expect(result.map(&:id)).to not_include(other_user.id)
      end
    end

    context 'when there is a user who has passed the threshold' do
      before do
        create(:pipl_user, initial_email_sent_at: threshold - 2.days, user: blocked_user)
      end

      it "fetches the already-deleted user" do
        expect { pipl_deletable }.to not_change { pipl_deletable.count }
      end
    end
  end

  describe '.for_user' do
    let_it_be(:pipl_user) { create(:pipl_user) }
    let_it_be(:other_user) { create(:user) }
    let(:user) { pipl_user }

    subject(:for_user) { described_class.for_user(user) }

    it { is_expected.to eq(pipl_user) }

    context 'when there is no pipl user' do
      let(:user) { other_user }

      it { is_expected.to be_nil }
    end
  end

  describe '.untrack_access!' do
    let_it_be(:pipl_user) { create(:pipl_user) }

    subject(:untrack_access) { described_class.untrack_access!(user) }

    context 'when the params is not a user instance' do
      let!(:user) { pipl_user }

      it 'does not untrack PIPL access' do
        expect { untrack_access }.to not_change { ComplianceManagement::PiplUser.count }
      end
    end

    context 'when the param is a user instance' do
      let!(:user) { pipl_user.user }

      subject(:untrack_access) { described_class.untrack_access!(user) }

      it 'deletes the record' do
        expect { untrack_access }.to change { ComplianceManagement::PiplUser.count }.by(-1)
        expect { user.reload }.not_to raise_error
      end
    end
  end

  describe '.track_access' do
    let!(:user) { create(:user) }

    subject(:track_access) { described_class.track_access(user) }

    it 'tracks PIPL access' do
      expect { track_access }.to change { ComplianceManagement::PiplUser.count }.by(1)
      expect(user.pipl_user.present?).to be(true)
    end
  end

  describe '#recently_tracked?', :freeze_time do
    let_it_be_with_reload(:pipl_user) { create(:pipl_user) }

    subject(:recently_tracked) { pipl_user.recently_tracked? }

    it { is_expected.to be(true) }

    context 'when the user was not tracked withing the past 24 hours' do
      before_all do
        pipl_user.update!(last_access_from_pipl_country_at: 25.hours.ago)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#pipl_access_end_date' do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: Time.zone.today) }

    subject(:pipl_access_end_date) { pipl_user.pipl_access_end_date }

    it 'returns the pipl deadline', :freeze_time do
      expect(pipl_access_end_date).to eq(Time.zone.today + described_class::NOTICE_PERIOD)
    end

    context 'when an email has not been sent' do
      before do
        pipl_user.update!(initial_email_sent_at: nil)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#block_threshold_met?', :freeze_time do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: Time.zone.today) }

    subject(:block_threshold_met?) { pipl_user.block_threshold_met? }

    it 'is not met' do
      expect(block_threshold_met?).to be(false)
    end

    context 'when the notice period has passed' do
      before do
        pipl_user.update!(initial_email_sent_at: described_class::NOTICE_PERIOD.ago)
      end

      it 'is met' do
        expect(block_threshold_met?).to be(true)
      end
    end

    context 'when more days than the notice period have passed' do
      before do
        pipl_user.update!(initial_email_sent_at: described_class::NOTICE_PERIOD.ago - 2.days)
      end

      it 'is met' do
        expect(block_threshold_met?).to be(true)
      end
    end

    context 'when the initial email has not been sent' do
      before do
        pipl_user.update!(initial_email_sent_at: nil)
      end

      it 'is not met' do
        expect(block_threshold_met?).to be(false)
      end
    end
  end

  describe '#deletion_threshold_met?', :freeze_time do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: Time.zone.today) }

    subject(:deletion_threshold_met?) { pipl_user.deletion_threshold_met? }

    it 'is not met' do
      expect(deletion_threshold_met?).to be(false)
    end

    context 'when more days than the deletion period have passed' do
      before do
        pipl_user.update!(initial_email_sent_at: described_class::DELETION_PERIOD.ago - 2.days)
      end

      it 'is met' do
        expect(deletion_threshold_met?).to be(true)
      end
    end

    context 'when the deletion period has passed' do
      before do
        pipl_user.update!(initial_email_sent_at: described_class::DELETION_PERIOD.ago)
      end

      it 'is met' do
        expect(deletion_threshold_met?).to be(true)
      end
    end

    context 'when the initial email has not been sent' do
      before do
        pipl_user.update!(initial_email_sent_at: nil)
      end

      it 'is not met' do
        expect(deletion_threshold_met?).to be(false)
      end
    end
  end

  describe '#reset_notification!' do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: Time.zone.today) }

    subject(:reset_notification!) { pipl_user.reset_notification! }

    it 'sets the timestamp to nil', :freeze_time do
      expect { reset_notification! }
        .to change { pipl_user.reload.initial_email_sent_at }
              .from(Time.zone.today)
              .to(nil)
    end
  end

  describe '#remaining_pipl_access_days' do
    let(:pipl_user) { create(:pipl_user, initial_email_sent_at: 10.days.ago) }

    subject(:remaining_pipl_access_days) { pipl_user.remaining_pipl_access_days }

    it 'calculate the remaining pipl access days', :freeze_time do
      expect(remaining_pipl_access_days).to be(50)
    end

    context 'when email is not sent yet' do
      let(:pipl_user) { create(:pipl_user, initial_email_sent_at: nil) }

      it 'returns null' do
        expect(remaining_pipl_access_days).to be_nil
      end
    end
  end
end
