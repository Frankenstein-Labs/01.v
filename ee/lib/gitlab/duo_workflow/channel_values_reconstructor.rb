# frozen_string_literal: true

module Gitlab
  module DuoWorkflow
    # Rebuilds a checkpoint's channel_values from incremental checkpoint blobs.
    # Each blob is a per-step delta (zlib-compressed JSON) for one (channel,
    # version); step_action carries the reducer signal -- a compaction replaces,
    # anything else appends. Pass blobs from a single ancestor chain (see
    # Ai::DuoWorkflows::Workflow#accumulated_blobs_for); off-chain blobs derive
    # from a different base and must not be mixed in.
    class ChannelValuesReconstructor
      include ::Gitlab::Utils::StrongMemoize

      COMPACTION = 'compaction'
      CONVERSATION = 'conversation'
      USER_MESSAGE = 'user'

      CorruptBlobError = Class.new(StandardError)

      # Decode a single blob's `data` (zlib-compressed JSON) to its Ruby value.
      # Exposed so callers that need just one blob (e.g. the tail of a channel)
      # can decode without instantiating a full reconstruction. Corruption isn't
      # expected (our gateway writes valid zlib JSON); raise rather than skip, so
      # a bad blob fails the read instead of returning inconsistent values.
      def self.decode(data)
        ::Gitlab::Json.safe_parse(Zlib::Inflate.inflate(data))
      rescue Zlib::Error, JSON::ParserError => e
        raise CorruptBlobError, "Failed to decode checkpoint blob: #{e.message}"
      end

      def initialize(blobs)
        @blobs = blobs
      end

      def channel_values
        blobs_by_channel.keys.index_with { |channel| fold(channel) }
      end

      # Fold one channel's FULL history for display. Unlike #channel_values, which
      # anchors at the last compaction to rebuild agent state, this keeps every
      # conversation delta and drops mid-stream compaction snapshots (internal
      # summaries and restart re-seeds whose detail is already in the deltas). Only
      # the earliest snapshot seeds the base. Pass blobs from the full ancestor
      # chain across all groups (Workflow#history_blobs_for).
      #
      # `ancestry` maps thread_ts -> parent_ts for that chain; every entry is stamped
      # with the checkpoint that introduced it (see #stamped).
      def channel_history(channel, ancestry, alternatives)
        # Prefer the conversation delta: this fold drops mid-stream compactions,
        # so a colliding compaction would lose the version's messages.
        ordered_blobs_for(channel, prefer: CONVERSATION).reduce(nil) do |value, blob|
          if blob.step_action == COMPACTION
            value.nil? ? stamped(blob, ancestry, alternatives) : value
          else
            append(value, stamped(blob, ancestry, alternatives))
          end
        end
      end

      # Every value a channel took over the session, oldest first. Each recorded
      # change is one entry, so plan and status changes stay visible instead of
      # collapsing to the final value. Array deltas (like ui_chat_log message
      # batches) are expanded into the list. Compaction snapshots are internal
      # re-seeds, so we skip them, except the first blob in the chain, which seeds
      # state from before the first recorded change. We anchor that skip on the
      # position, not on whether a change was emitted, so a compaction after
      # empty-array deltas still drops instead of leaking the summary. Pass blobs
      # from the full ancestor chain across all groups (Workflow#full_history_blobs).
      def channel_changes(channel)
        # Prefer the conversation delta: like #channel_history, this drops
        # mid-stream compactions, so a colliding compaction would lose the change.
        ordered = ordered_blobs_for(channel, prefer: CONVERSATION)
        ordered.each_with_index.each_with_object([]) do |(blob, index), changes|
          next if blob.step_action == COMPACTION && index > 0

          value = decode(blob.data)
          value.is_a?(Array) ? changes.concat(value) : changes.push(value)
        end
      end

      private

      # Anchor at the last compaction so the fold is O(deltas since it), not
      # O(chain length); safe only for a single ancestor chain (see #initialize).
      # Prefer the compaction: it carries the full value, so anchoring on it keeps
      # the fold short.
      def fold(channel)
        ordered = ordered_blobs_for(channel, prefer: COMPACTION)

        last_compaction = ordered.rindex { |blob| blob.step_action == COMPACTION }
        ordered = ordered.drop(last_compaction) if last_compaction

        ordered.reduce(nil) { |value, blob| apply(value, blob) }
      end

      # Blobs come in chain order (id order, see Workflow#accumulated_blobs_for), not
      # version order, because version numbers can repeat after a compaction resets the
      # writer's counter. group_by keeps each version at its first occurrence, so no sort.
      def ordered_blobs_for(channel, prefer:)
        # Dedup by thread_ts and version together, not version alone. A version can repeat
        # legitimately across thread groups, and grouping by version alone would drop it.
        blobs_by_channel.fetch(channel, [])
          .group_by { |blob| [blob.thread_ts, blob.version] }
          .values
          # A force_rewrite can store both a delta and a compaction under the same version.
          # `prefer` picks the winning step_action, so the result never depends on insertion
          # order (https://gitlab.com/gitlab-org/gitlab/-/issues/604371).
          .map { |rows| rows.find { |blob| blob.step_action == prefer } || rows.first }
      end

      # Memoized: one group_by(&:channel) pass covers all channels, not a rescan per channel.
      def blobs_by_channel
        @blobs.group_by(&:channel)
      end
      strong_memoize_attr :blobs_by_channel

      # A compaction replaces the running value; anything else appends.
      def apply(value, blob)
        delta = decode(blob.data)
        return delta if blob.step_action == COMPACTION

        append(value, delta)
      end

      # Append `delta` onto the running `value` in place. Shared by #fold (agent
      # state) and #channel_history (display) so both grow lists identically.
      def append(value, delta)
        case delta
        when Array
          # concat (not +) so folding k appends is O(k), not O(k^2); delta is
          # freshly decoded, so it never aliases the compaction snapshot.
          value ? value.concat(delta) : delta
        when Hash
          # dict-of-list channel: append each key's tail to the accumulated list.
          return delta unless value.is_a?(Hash)

          delta.each do |key, tail|
            if tail.is_a?(Array)
              (value[key] ||= []).concat(tail)
            else
              value[key] = tail
            end
          end
          value
        else
          delta
        end
      end

      # Stamp each message with the checkpoint that introduced it: the blob's own
      # thread_ts and that checkpoint's parent_ts -- the point a client forks from.
      # A user message anchors its turn, so it also carries the alternative count.
      def stamped(blob, ancestry, alternatives)
        value = decode(blob.data)
        return value unless value.is_a?(Array)

        value.each do |entry|
          next unless entry.is_a?(Hash)

          entry['thread_ts'] = blob.thread_ts
          entry['parent_ts'] = ancestry[blob.thread_ts]
          next unless entry['message_type'] == USER_MESSAGE

          entry['alternative_count'] = alternatives.fetch(blob.thread_ts, 0)
        end
      end

      def decode(data)
        self.class.decode(data)
      end
    end
  end
end
