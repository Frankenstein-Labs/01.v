# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Integrations::JiraTrackerData, feature_category: :team_planning do
  describe 'jira verification fields' do
    subject(:tracker_data) { build(:jira_tracker_data) }

    describe '#jira_check_enabled' do
      it 'returns false when the attribute is nil' do
        tracker_data.write_attribute(:jira_check_enabled, nil)

        expect(tracker_data.jira_check_enabled).to be(false)
      end

      it 'returns true when the attribute is true' do
        tracker_data.write_attribute(:jira_check_enabled, true)

        expect(tracker_data.jira_check_enabled).to be(true)
      end
    end

    describe '#jira_exists_check_enabled' do
      it 'returns false when the attribute is nil' do
        tracker_data.write_attribute(:jira_exists_check_enabled, nil)

        expect(tracker_data.jira_exists_check_enabled).to be(false)
      end

      it 'returns true when the attribute is true' do
        tracker_data.write_attribute(:jira_exists_check_enabled, true)

        expect(tracker_data.jira_exists_check_enabled).to be(true)
      end
    end

    describe '#jira_assignee_check_enabled' do
      it 'returns false when the attribute is nil' do
        tracker_data.write_attribute(:jira_assignee_check_enabled, nil)

        expect(tracker_data.jira_assignee_check_enabled).to be(false)
      end

      it 'returns true when the attribute is true' do
        tracker_data.write_attribute(:jira_assignee_check_enabled, true)

        expect(tracker_data.jira_assignee_check_enabled).to be(true)
      end
    end

    describe '#jira_status_check_enabled' do
      it 'returns false when the attribute is nil' do
        tracker_data.write_attribute(:jira_status_check_enabled, nil)

        expect(tracker_data.jira_status_check_enabled).to be(false)
      end

      it 'returns true when the attribute is true' do
        tracker_data.write_attribute(:jira_status_check_enabled, true)

        expect(tracker_data.jira_status_check_enabled).to be(true)
      end
    end

    describe '#jira_allowed_statuses' do
      it 'returns an empty array when jira_allowed_statuses_string is blank' do
        tracker_data.write_attribute(:jira_allowed_statuses_string, '')

        expect(tracker_data.jira_allowed_statuses).to eq([])
      end

      it 'returns an array of status strings when jira_allowed_statuses_string is not blank' do
        tracker_data.write_attribute(:jira_allowed_statuses_string, 'Ready,In Progress,Review')

        expect(tracker_data.jira_allowed_statuses).to match_array(['Ready', 'In Progress', 'Review'])
      end
    end

    describe '#jira_allowed_statuses=' do
      it 'saves a comma-separated string with array input' do
        tracker_data.jira_allowed_statuses = ['Ready', 'In Progress', 'Review']

        expect(tracker_data.read_attribute(:jira_allowed_statuses_string)).to eq('Ready,In Progress,Review')
      end

      it 'saves a comma-separated string with empty input' do
        tracker_data.jira_allowed_statuses = []

        expect(tracker_data.read_attribute(:jira_allowed_statuses_string)).to eq('')
      end

      it 'saves a comma-separated string with nil input' do
        tracker_data.jira_allowed_statuses = nil

        expect(tracker_data.read_attribute(:jira_allowed_statuses_string)).to eq('')
      end

      it 'removes duplicates and blank entries' do
        tracker_data.jira_allowed_statuses = ['Ready', 'In Progress', '', 'In Progress', 'Review']

        expect(tracker_data.read_attribute(:jira_allowed_statuses_string)).to eq('Ready,In Progress,Review')
      end
    end

    describe '#jira_allowed_statuses_as_string' do
      it 'returns an empty string when jira_allowed_statuses is empty' do
        allow(tracker_data).to receive(:jira_allowed_statuses).and_return([])

        expect(tracker_data.jira_allowed_statuses_as_string).to eq('')
      end

      it 'returns a comma-separated string when jira_allowed_statuses is not empty' do
        allow(tracker_data).to receive(:jira_allowed_statuses).and_return(['Ready', 'In Progress', 'Review'])

        expect(tracker_data.jira_allowed_statuses_as_string).to eq('Ready,In Progress,Review')
      end
    end

    describe '#jira_allowed_statuses_as_string=' do
      it 'converts the string to an array and calls jira_allowed_statuses=' do
        expect(tracker_data).to receive(:jira_allowed_statuses=).with(['Ready', 'In Progress', 'Review'])

        tracker_data.jira_allowed_statuses_as_string = 'Ready,In Progress,Review'
      end

      it 'handles spaces correctly' do
        expect(tracker_data).to receive(:jira_allowed_statuses=).with(['Ready', 'In Progress', 'Review'])

        tracker_data.jira_allowed_statuses_as_string = 'Ready, In Progress , Review'
      end

      it 'handles empty strings correctly' do
        expect(tracker_data).to receive(:jira_allowed_statuses=).with([])

        tracker_data.jira_allowed_statuses_as_string = ''
      end

      it 'handles nil values correctly' do
        expect(tracker_data).to receive(:jira_allowed_statuses=).with([])

        tracker_data.jira_allowed_statuses_as_string = nil
      end
    end
  end
end
