# frozen_string_literal: true

module Ai
  module Governance
    class MetricsTimeframe
      WINDOWS = {
        last_24_hours: { duration: 24.hours, step: 1.hour },
        last_7_days: { duration: 7.days, step: 1.day },
        last_30_days: { duration: 30.days, step: 1.day }
      }.freeze

      attr_reader :from, :to, :previous_from, :step

      def initialize(timeframe)
        window = WINDOWS.fetch(timeframe.to_sym)
        @step = window[:step]
        @to = Time.current.utc
        @from = align(@to - window[:duration])
        @previous_from = @from - window[:duration]
      end

      def hourly?
        step == 1.hour
      end

      def bucket_starts
        series = []
        cursor = from
        while cursor <= to
          series << cursor
          cursor += step
        end
        series
      end

      private

      def align(time)
        hourly? ? time.beginning_of_hour : time.beginning_of_day
      end
    end
  end
end
