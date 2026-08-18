# frozen_string_literal: true

# Provides `effective_time_window` which caps the configured time_window
# to not exceed the interval until the next scheduled run.
#
# Includers must implement:
# - `calculate_next_run_at`
# - `time_window_seconds`
module Security
  module TimeWindowCappable
    extend ActiveSupport::Concern

    def effective_time_window(next_run_at = nil)
      return unless time_window_seconds

      now = Time.zone.now
      next_run_at ||= calculate_next_run_at(now)
      seconds_until_next_run = (next_run_at - now).to_i

      [time_window_seconds, seconds_until_next_run].min
    end
  end
end
