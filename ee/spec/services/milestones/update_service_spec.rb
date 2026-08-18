# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Milestones::UpdateService, feature_category: :team_planning do
  describe '#execute' do
    context 'refresh related epic dates' do
      let(:start_date) { 1.day.from_now.to_date }
      let(:due_date) { 3.days.from_now.to_date }
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:user) { build(:user) }
      let_it_be_with_reload(:milestone) { create(:milestone, project: project) }
      let_it_be_with_reload(:epic) { create(:epic, group: group) }
      let_it_be(:issue) { create(:issue, milestone: milestone, epic: epic, project: project) }

      subject(:update_milestone) { described_class.new(project, user, params).execute(milestone) }

      context 'when due date changes' do
        let(:params) { { due_date: due_date } }
        let(:expected_attributes) do
          {
            start_date: nil,
            start_date_sourcing_milestone: nil,
            due_date: due_date,
            due_date_sourcing_milestone: milestone
          }
        end

        it 'updates milestone sourced dates when due date changes' do
          update_milestone

          expect(epic.reload).to have_attributes(expected_attributes)
          expect(epic.work_item.dates_source).to have_attributes(expected_attributes)
        end
      end

      context 'when start date changes' do
        let(:params) { { start_date: start_date } }
        let(:expected_attributes) do
          {
            start_date: start_date,
            start_date_sourcing_milestone: milestone,
            due_date: nil,
            due_date_sourcing_milestone: nil
          }
        end

        it 'updates milestone sourced dates when start date changes' do
          update_milestone

          expect(epic.reload).to have_attributes(expected_attributes)
          expect(epic.work_item.dates_source).to have_attributes(expected_attributes)
        end
      end

      context 'when both start and due date changes' do
        let(:params) { { start_date: start_date, due_date: due_date } }
        let(:expected_attributes) do
          {
            start_date: start_date,
            start_date_sourcing_milestone: milestone,
            due_date: due_date,
            due_date_sourcing_milestone: milestone
          }
        end

        it 'updates milestone sourced dates when start date changes' do
          update_milestone

          expect(epic.reload).to have_attributes(expected_attributes)
          expect(epic.work_item.dates_source).to have_attributes(expected_attributes)
        end
      end
    end
  end
end
