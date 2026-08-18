# frozen_string_literal: true

module DependencyManagement
  module SecurityUpdate
    # Cooldown between re-resolutions of an open remediation merge request, so an open MR
    # picks up a newer patched version without running an update workload on every pipeline.
    #
    # Owns the window for both sides: CreateMergeRequestService starts it whenever an MR is
    # brought up to date, and SchedulerService consumes it when deciding to refresh. Losing
    # the key costs at most one extra refresh, so a plain expiring key is enough.
    module RefreshCooldown
      PERIOD = 8.hours
      KEY_PREFIX = 'dependency_management:remediation_refresh'

      # Starts the window, so the merge request is left alone until it elapses. Called when
      # the merge request is created or updated: it already reflects the latest resolution.
      def self.start(merge_request)
        ::Gitlab::Redis::SharedState.with do |redis|
          redis.set(key_for(merge_request), 1, ex: PERIOD.to_i)
        end
      rescue ::Redis::BaseError, ::RedisClient::Error => e
        ::Gitlab::ErrorTracking.track_exception(e, merge_request_id: merge_request.id)

        nil
      end

      # @return [Boolean] true once the window has elapsed and the merge request may be
      # re-resolved. Consumes the window, so a refresh is attempted at most once per window
      # even when it never reaches the merge request - e.g. its workload fails. The set and
      # the read are one operation, so concurrent schedulers cannot both claim it.
      #
      # Reports false when Redis is unreachable: the cooldown cannot be established, so the
      # safe answer is to leave the merge request alone rather than refresh every open
      # remediation on every pipeline. A conflicted one is still picked up, since that check
      # does not go through here.
      def self.elapsed?(merge_request)
        ::Gitlab::Redis::SharedState.with do |redis|
          redis.set(key_for(merge_request), 1, ex: PERIOD.to_i, nx: true)
        end
      rescue ::Redis::BaseError, ::RedisClient::Error => e
        ::Gitlab::ErrorTracking.track_exception(e, merge_request_id: merge_request.id)

        false
      end

      def self.key_for(merge_request)
        "#{KEY_PREFIX}:#{merge_request.id}"
      end
      private_class_method :key_for
    end
  end
end
