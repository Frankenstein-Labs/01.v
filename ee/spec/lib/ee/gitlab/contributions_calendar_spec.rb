# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ContributionsCalendar, feature_category: :user_profile do
  let_it_be_with_reload(:contributor) { create(:user) }
  let_it_be_with_reload(:current_user) { create(:user) }

  let_it_be(:public_group) do
    create(:group, :public) { |group| create(:group_member, user: contributor, group: group) }
  end

  let_it_be(:private_group) do
    create(:group, :private) { |group| create(:group_member, user: contributor, group: group) }
  end

  let_it_be(:today) { Time.now.utc.to_date }

  let(:calendar) { described_class.new(contributor, current_user) }

  let!(:public_group_epic_created_event) { create_epic_event(public_group, today, action: :created) }
  let!(:public_group_epic_closed_event) { create_epic_event(public_group, today, action: :closed) }
  let!(:public_group_epic_commented_event) { create_note_event(public_group, today) }

  let!(:old_public_group_event) { create_epic_event(public_group, today - 7.days) }
  let!(:private_group_event) { create_epic_event(private_group, today) }

  describe '#activity_dates' do
    subject(:activity_dates) { calendar.activity_dates }

    context 'when current user is not member of private group' do
      it 'counts epic events correctly' do
        expect(activity_dates[today]).to eq(3)
      end
    end

    context 'when current user is member of private group' do
      before do
        create(:group_member, user: current_user, group: private_group)
      end

      it 'counts epic events correctly' do
        expect(activity_dates[today]).to eq(4)
      end
    end

    context 'when contributor has opted-in for private contributions' do
      before do
        contributor.update!(include_private_contributions: true)
      end

      it 'counts public and private epic events regardless of feature availability' do
        expect(activity_dates[today]).to eq(4)
      end
    end
  end

  describe '#events_by_date' do
    subject(:events) { calendar.events_by_date(today) }

    context 'when current user is not member of private group' do
      it 'returns expected epic events for a given date' do
        expect(events).to contain_exactly(
          public_group_epic_created_event, public_group_epic_closed_event, public_group_epic_commented_event
        )
      end
    end

    context 'when current user is member of private group' do
      before do
        create(:group_member, user: current_user, group: private_group)
      end

      it 'returns expected epic events for a given date' do
        expect(events).to contain_exactly(
          public_group_epic_created_event, public_group_epic_closed_event, public_group_epic_commented_event,
          private_group_event
        )
      end
    end

    context 'when contributor has opted-in for private contributions' do
      before do
        contributor.update!(include_private_contributions: true)
      end

      it 'returns public and private epic events for a given date regardless of feature availability' do
        expect(events).to contain_exactly(
          public_group_epic_created_event, public_group_epic_closed_event, public_group_epic_commented_event,
          private_group_event
        )
      end
    end
  end

  def create_note_event(group, day, hour = 0)
    epic = create(:epic, group: group, author: contributor)
    note = create(:note, author: contributor, noteable: epic)

    create_event(group, day, hour, target_type: 'Note', target: note, action: :commented)
  end

  def create_epic_event(group, day, hour = 0, action: :created)
    epic = create(:epic, group: group, author: contributor)

    create_event(group, day, hour, target_type: 'Epic', target: epic, action: action)
  end

  def create_event(group, day, hour = 0, target_type:, target:, action:)
    create(:event,
      group: group,
      project: nil,
      target_type: target_type,
      target: target,
      action: action,
      author: contributor,
      created_at: DateTime.new(day.year, day.month, day.day, hour)
    )
  end
end
