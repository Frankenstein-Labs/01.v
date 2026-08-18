# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Security::Orchestration::PipelineExecutionPolicies::Intervals, feature_category: :security_policy_management do
  describe '.from_schedules' do
    subject(:interval) { described_class.from_schedules([schedule]).first }

    context 'with daily schedules' do
      let(:schedule) do
        {
          "type" => "daily",
          "start_time" => "09:00",
          "time_window" => {
            "value" => 28800,
            "distribution" => "random"
          },
          "timezone" => "UTC"
        }
      end

      it 'generates correct interval data' do
        expect(interval.cron).to eq("0 9 * * *")
        expect(interval.time_window).to eq(8.hours)
        expect(interval.time_zone).to eq("UTC")
      end

      context 'when timezone is not specified' do
        let(:schedule) do
          {
            "type" => "daily",
            "start_time" => "09:00",
            "time_window" => {
              "value" => 28800,
              "distribution" => "random"
            }
          }
        end

        it "defaults to #{described_class::DEFAULT_TIMEZONE}" do
          expect(interval.time_zone).to eq(described_class::DEFAULT_TIMEZONE)
        end
      end
    end

    context 'with weekly schedules' do
      let(:schedule) do
        {
          "type" => "weekly",
          "days" => %w[Monday Wednesday Friday],
          "start_time" => "10:30",
          "time_window" => {
            "value" => 28800,
            "distribution" => "random"
          },
          "timezone" => "America/New_York"
        }
      end

      it 'generates correct interval data' do
        expect(interval.cron).to eq("30 10 * * 1,3,5")
        expect(interval.time_window).to eq(8.hours)
        expect(interval.time_zone).to eq("America/New_York")
      end
    end

    context 'with monthly schedules' do
      let(:schedule) do
        {
          "type" => "monthly",
          "days_of_month" => [1, 15, 30],
          "start_time" => "03:00",
          "time_window" => {
            "value" => 7200,
            "distribution" => "random"
          },
          "timezone" => "Europe/London"
        }
      end

      it 'generates correct interval data' do
        expect(interval.cron).to eq("0 3 1,15,30 * *")
        expect(interval.time_window).to eq(2.hours)
        expect(interval.time_zone).to eq("Europe/London")
      end
    end

    context 'with unknown schedule type' do
      let(:schedule) do
        {
          "type" => "unknown",
          "start_time" => "00:00",
          "time_window" => {
            "value" => 7200,
            "distribution" => "random"
          }
        }
      end

      specify do
        expect { interval }.to raise_error(described_class::UnsupportedScheduleTypeError)
      end
    end

    context 'with weekly schedule when days are missing' do
      let(:schedule) do
        {
          "type" => "weekly",
          "start_time" => "10:30",
          "time_window" => {
            "value" => 28800,
            "distribution" => "random"
          },
          "timezone" => "UTC"
        }
      end

      it 'handles missing days gracefully by defaulting to the first day of the week' do
        expect(interval.cron).to eq("30 10 * * 0")
      end

      it 'produces a valid cron expression parseable by CronParser' do
        cron_parser = Gitlab::Ci::CronParser.new(interval.cron, 'UTC')

        expect(cron_parser.cron_valid?).to be(true)
      end
    end

    context 'with monthly schedule when days_of_month are missing' do
      let(:schedule) do
        {
          "type" => "monthly",
          "start_time" => "03:00",
          "time_window" => {
            "value" => 7200,
            "distribution" => "random"
          },
          "timezone" => "UTC"
        }
      end

      it 'handles missing days_of_month gracefully by defaulting to the first day of the month' do
        expect(interval.cron).to eq("0 3 1 * *")
      end

      it 'produces a valid cron expression parseable by CronParser' do
        cron_parser = Gitlab::Ci::CronParser.new(interval.cron, 'UTC')

        expect(cron_parser.cron_valid?).to be(true)
      end
    end

    context 'when start_time is not provided' do
      let(:schedule) do
        {
          "type" => "daily",
          "time_window" => {
            "value" => 28800,
            "distribution" => "random"
          },
          "timezone" => "UTC"
        }
      end

      it 'defaults to midnight' do
        expect(interval.cron).to eq("0 0 * * *")
      end
    end

    context 'with multiple schedules' do
      let(:schedules) do
        [
          {
            "type" => "daily",
            "start_time" => "09:00",
            "time_window" => {
              "value" => 28800,
              "distribution" => "random"
            }
          },
          {
            "type" => "weekly",
            "days" => %w[Monday Saturday Sunday],
            "start_time" => "10:00",
            "time_window" => {
              "value" => 21600,
              "distribution" => "random"
            }
          }
        ]
      end

      subject(:intervals) { described_class.from_schedules(schedules) }

      it 'maps schedules correctly' do
        expect(intervals.size).to be(2)

        daily = intervals.first
        expect(daily.cron).to eq("0 9 * * *")
        expect(daily.time_window).to eq(8.hours)
        expect(daily.time_zone).to eq(described_class::DEFAULT_TIMEZONE)

        weekend = intervals.last
        expect(weekend.cron).to eq("0 10 * * 1,6,0")
        expect(weekend.time_window).to eq(6.hours)
        expect(weekend.time_zone).to eq(described_class::DEFAULT_TIMEZONE)
      end
    end
  end
end
