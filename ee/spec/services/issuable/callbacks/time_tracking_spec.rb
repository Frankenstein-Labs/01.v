# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::Callbacks::TimeTracking, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:reporter) do
    create(:user, reporter_of: group)
  end

  let_it_be(:guest) do
    create(:user, guest_of: group)
  end

  let(:current_user) { reporter }
  let(:non_string_params) do
    {
      time_estimate: 12.hours.to_i,
      spend_time: {
        duration: 2.hours.to_i,
        user_id: current_user.id,
        spent_at: Date.today
      }
    }
  end

  let(:string_params) do
    {
      time_estimate: "12h",
      timelog: {
        time_spent: "2h",
        summary: "some summary"
      }
    }
  end

  let(:callback) { described_class.new(issuable: issuable, current_user: current_user, params: params) }

  before do
    stub_licensed_features(epics: true)
  end

  describe '#after_initialize' do
    shared_examples 'raises an Error' do
      it { expect { subject }.to raise_error(::Issuable::Callbacks::Base::Error, message) }
    end

    shared_examples 'sets work item time tracking data' do
      it 'correctly sets time tracking data', :aggregate_failures do
        callback.after_initialize

        expect(issuable.time_spent).to eq(2.hours.to_i)
        expect(issuable.time_estimate).to eq(12.hours.to_i)
        expect(issuable.timelogs.last.time_spent).to eq(2.hours.to_i)
      end
    end

    shared_examples 'does not set work item time tracking data' do
      it 'does not change work item time tracking data', :aggregate_failures do
        callback.after_initialize

        if issuable.persisted?
          expect(issuable.time_estimate).to eq(2.hours.to_i)
          expect(issuable.total_time_spent).to eq(3.hours.to_i)
          expect(issuable.timelogs.last.time_spent).to eq(3.hours.to_i)
        else
          expect(issuable.time_estimate).to eq(0)
          expect(issuable.time_spent).to eq(nil)
          expect(issuable.timelogs).to be_empty
        end
      end
    end

    context 'when at group level' do
      let(:issuable) { group_work_item }

      context 'and work item is not persisted' do
        let(:group_work_item) { build(:work_item, :task, :group_level, namespace: group) }

        context 'with non string params' do
          let(:params) { non_string_params }

          it_behaves_like 'sets work item time tracking data'
        end

        context 'with string params' do
          let(:params) { string_params }

          it_behaves_like 'sets work item time tracking data'
        end

        context 'when time tracking param is not present' do
          let(:params) { {} }

          it_behaves_like 'does not set work item time tracking data'
        end
      end

      context 'and work item is persisted' do
        let_it_be_with_reload(:group_work_item) do
          create(:work_item, :task, :group_level, namespace: group, time_estimate: 2.hours.to_i)
        end

        let_it_be(:timelog) { create(:timelog, issue: group_work_item, time_spent: 3.hours.to_i) }

        context 'with non string params' do
          let(:params) { non_string_params }

          it_behaves_like 'sets work item time tracking data'
        end

        context 'with string params' do
          let(:params) { string_params }

          it_behaves_like 'sets work item time tracking data'
        end
      end

      context 'without group level work item license' do
        before do
          stub_licensed_features(epics: false)
        end

        context 'and work item is not persisted' do
          let(:group_work_item) { build(:work_item, :task, :group_level, namespace: group) }

          context 'with non string params' do
            let(:params) { non_string_params }

            it_behaves_like 'does not set work item time tracking data'
          end

          context 'with string params' do
            let(:params) { string_params }

            it_behaves_like 'does not set work item time tracking data'
          end
        end

        context 'and work item is persisted' do
          let_it_be_with_reload(:group_work_item) do
            create(:work_item, :task, :group_level, namespace: group, time_estimate: 2.hours.to_i)
          end

          let_it_be(:timelog) { create(:timelog, issue: group_work_item, time_spent: 3.hours.to_i) }

          context 'with non string params' do
            let(:params) { non_string_params }

            it_behaves_like 'does not set work item time tracking data'
          end

          context 'with string params' do
            let(:params) { string_params }

            it_behaves_like 'does not set work item time tracking data'
          end
        end
      end
    end
  end
end
