# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['EscalationRuleInput'], feature_category: :incident_management do
  context 'mutually exclusive arguments' do
    let(:input) do
      {
        oncall_schedule_iid: schedule_iid,
        username: username,
        elapsed_time_seconds: 0,
        status: 'RESOLVED'
      }
    end

    let(:output) { input.merge(status: 'resolved', oncall_schedule_iid: schedule_iid&.to_s) }
    let(:schedule_iid) { nil }
    let(:username) { nil }

    subject { described_class.coerce_isolated_input(input).prepare.to_h }

    context 'with only on-call schedule provided' do
      let(:schedule_iid) { 3 }

      it { is_expected.to eq(output) }
    end

    context 'with only user schedule provided' do
      let(:username) { 'username' }

      it { is_expected.to eq(output) }
    end
  end

  it 'has specific fields' do
    allowed_args = %w[oncallScheduleIid username elapsedTimeSeconds status]

    expect(described_class.arguments.keys).to include(*allowed_args)
  end
end
