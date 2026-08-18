# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'pipeline_execution_schedule_policy_content.json', feature_category: :security_policy_management do
  let(:schema_path) do
    Rails.root.join("ee/app/validators/json_schemas/pipeline_execution_schedule_policy_content.json")
  end

  let(:schema) { JSONSchemer.schema(schema_path) }
  let(:policy) do
    {
      content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
      schedules: [{
        type: "daily",
        start_time: "00:00",
        time_window: { distribution: "random", value: 4000 }
      }]
    }
  end

  context 'when policy has no branches' do
    specify { expect(schema.valid?(policy)).to be true }
  end

  context 'when policy has branches' do
    before do
      policy[:schedules][0][:branches] = branches
    end

    context 'with a valid list of branches' do
      let(:branches) { %w[main develop feature-branch] }

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'with an empty list of branches' do
      let(:branches) { [] }

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'with too many branches' do
      let(:branches) { %w[branch1 branch2 branch3 branch4 branch5 branch6] }

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'with duplicated branches' do
      let(:branches) { %w[main main develop] }

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'with non-string branches' do
      let(:branches) { ["main", 123, "develop"] }

      specify { expect(schema.valid?(policy)).to be false }
    end
  end

  context 'when time_window value exceeds maximum' do
    before do
      policy[:schedules][0][:time_window][:value] = 2_629_747
    end

    it 'is invalid' do
      expect(schema.valid?(policy)).to be false
    end

    it 'returns a path-based error for time_window/value' do
      errors = schema.validate(policy).map { |e| JSONSchemer::Errors.pretty(e) }

      expect(errors).to include(
        a_string_matching(%r{/schedules/0/time_window/value.+maximum})
      )
      expect(errors).not_to include(
        a_string_matching(/maxItems/)
      )
    end
  end

  context 'when time_window value is below minimum' do
    before do
      policy[:schedules][0][:time_window][:value] = 100
    end

    it 'is invalid' do
      expect(schema.valid?(policy)).to be false
    end

    it 'returns a path-based error for time_window/value' do
      errors = schema.validate(policy).map { |e| JSONSchemer::Errors.pretty(e) }

      expect(errors).to include(
        a_string_matching(%r{/schedules/0/time_window/value.+minimum})
      )
    end
  end

  context 'with weekly schedule' do
    let(:policy) do
      {
        content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
        schedules: [{
          type: "weekly",
          days: %w[Monday Friday],
          start_time: "10:00",
          time_window: { distribution: "random", value: 4000 }
        }]
      }
    end

    specify { expect(schema.valid?(policy)).to be true }

    context 'when days is missing' do
      before do
        policy[:schedules][0].delete(:days)
      end

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'when time_window value exceeds maximum' do
      before do
        policy[:schedules][0][:time_window][:value] = 2_629_747
      end

      it 'returns a path-based error for time_window/value' do
        errors = schema.validate(policy).map { |e| JSONSchemer::Errors.pretty(e) }

        expect(errors).to include(
          a_string_matching(%r{/schedules/0/time_window/value.+maximum})
        )
      end
    end
  end

  context 'with monthly schedule' do
    let(:policy) do
      {
        content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
        schedules: [{
          type: "monthly",
          days_of_month: [1, 15],
          start_time: "10:00",
          time_window: { distribution: "random", value: 4000 }
        }]
      }
    end

    specify { expect(schema.valid?(policy)).to be true }

    context 'when days_of_month is missing' do
      before do
        policy[:schedules][0].delete(:days_of_month)
      end

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'when time_window value exceeds maximum' do
      before do
        policy[:schedules][0][:time_window][:value] = 2_629_747
      end

      it 'returns a path-based error for time_window/value' do
        errors = schema.validate(policy).map { |e| JSONSchemer::Errors.pretty(e) }

        expect(errors).to include(
          a_string_matching(%r{/schedules/0/time_window/value.+maximum})
        )
      end
    end
  end

  describe 'type-specific property restrictions' do
    context 'when daily schedule has days property' do
      let(:policy) do
        {
          content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
          schedules: [{
            type: "daily",
            start_time: "00:00",
            time_window: { distribution: "random", value: 4000 },
            days: %w[Monday]
          }]
        }
      end

      it 'is invalid because days is only allowed for weekly schedules' do
        expect(schema.valid?(policy)).to be false
      end
    end

    context 'when daily schedule has days_of_month property' do
      let(:policy) do
        {
          content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
          schedules: [{
            type: "daily",
            start_time: "00:00",
            time_window: { distribution: "random", value: 4000 },
            days_of_month: [1, 15]
          }]
        }
      end

      it 'is invalid because days_of_month is only allowed for monthly schedules' do
        expect(schema.valid?(policy)).to be false
      end
    end

    context 'when weekly schedule has days_of_month property' do
      let(:policy) do
        {
          content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
          schedules: [{
            type: "weekly",
            days: %w[Monday],
            start_time: "00:00",
            time_window: { distribution: "random", value: 4000 },
            days_of_month: [1]
          }]
        }
      end

      it 'is invalid because days_of_month is only allowed for monthly schedules' do
        expect(schema.valid?(policy)).to be false
      end
    end

    context 'when monthly schedule has days property' do
      let(:policy) do
        {
          content: { include: [{ project: "compliance-project", file: "compliance-pipeline.yml" }] },
          schedules: [{
            type: "monthly",
            days_of_month: [1],
            start_time: "00:00",
            time_window: { distribution: "random", value: 4000 },
            days: %w[Monday]
          }]
        }
      end

      it 'is invalid because days is only allowed for weekly schedules' do
        expect(schema.valid?(policy)).to be false
      end
    end
  end

  describe 'variables_override' do
    context 'when variables_override is valid' do
      before do
        policy[:variables_override] = { allowed: true }
      end

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'when variables_override has exceptions' do
      before do
        policy[:variables_override] = { allowed: false, exceptions: %w[MY_VAR OTHER_VAR] }
      end

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'when variables_override has dotenv setting' do
      before do
        policy[:variables_override] = { allowed: false, dotenv: 'allow_override' }
      end

      specify { expect(schema.valid?(policy)).to be true }
    end

    context 'when variables_override is missing allowed' do
      before do
        policy[:variables_override] = { exceptions: %w[MY_VAR] }
      end

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'when variables_override has invalid dotenv value' do
      before do
        policy[:variables_override] = { allowed: true, dotenv: 'invalid' }
      end

      specify { expect(schema.valid?(policy)).to be false }
    end

    context 'when variables_override has unknown properties' do
      before do
        policy[:variables_override] = { allowed: true, unknown_key: 'value' }
      end

      specify { expect(schema.valid?(policy)).to be false }
    end
  end
end
