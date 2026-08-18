# frozen_string_literal: true

RSpec.shared_context 'with Elasticsearch task status response context' do
  let(:not_found_response) do
    {
      "error" => {
        "root_cause" => [
          {
            "type" => "resource_not_found_exception",
            "reason" => "task [99YgTgMFRSC38-gIr1XM-A:290310] isn't running and hasn't stored its results"
          }
        ],
        "type" => "resource_not_found_exception",
        "reason" => "task [99YgTgMFRSC38-gIr1XM-A:290310] isn't running and hasn't stored its results"
      },
      "status" => 404
    }
  end

  let(:successful_response) do
    {
      "completed" => true,
      "task" => {
        "node" => "99YgTgMFRSC38-gIr1XM-A",
        "id" => 22472,
        "type" => "transport",
        "action" => "indices:data/write/reindex",
        "status" => {
          "slice_id" => 0,
          "total" => 39,
          "updated" => 39,
          "created" => 0,
          "deleted" => 0,
          "batches" => 1,
          "version_conflicts" => 0,
          "noops" => 0,
          "retries" => {
            "bulk" => 0,
            "search" => 0
          },
          "throttled_millis" => 0,
          "requests_per_second" => -1.0,
          "throttled_until_millis" => 0
        },
        "description" => "reindex from [gitlab-dev-issues-20231218] to [gitlab-dev-issues-20240105-reindex-7-0]",
        "start_time_in_millis" => 1704479577661,
        "running_time_in_nanos" => 8594250,
        "cancellable" => true,
        "cancelled" => false,
        "headers" => {}
      },
      "response" => {
        "took" => 8,
        "timed_out" => false,
        "slice_id" => 0,
        "total" => 39,
        "updated" => 39,
        "created" => 0,
        "deleted" => 0,
        "batches" => 1,
        "version_conflicts" => 0,
        "noops" => 0,
        "retries" => {
          "bulk" => 0,
          "search" => 0
        },
        "throttled" => "0s",
        "throttled_millis" => 0,
        "requests_per_second" => -1.0,
        "throttled_until" => "0s",
        "throttled_until_millis" => 0,
        "failures" => []
      }
    }
  end

  let(:error_response) do
    {
      "completed" => true,
      "task" => {
        "node" => "nkPdJlK5Q-GdrVdqCrtilg",
        "id" => 1323891533,
        "type" => "transport",
        "action" => "indices:data/write/reindex",
        "status" => {
          "slice_id" => 310,
          "total" => 0,
          "updated" => 0,
          "created" => 0,
          "deleted" => 0,
          "batches" => 0,
          "version_conflicts" => 0,
          "noops" => 0,
          "retries" => {
            "bulk" => 0,
            "search" => 0
          },
          "throttled_millis" => 0,
          "requests_per_second" => -1,
          "throttled_until_millis" => 0
        },
        "description" => "reindex from [gitlab-dev-issues-20231218] to [gitlab-dev-issues-20240105-reindex-7-0]",
        "start_time_in_millis" => 1702909471853,
        "running_time_in_nanos" => 40416471,
        "cancellable" => true,
        "cancelled" => false,
        "headers" => {
          "X-Opaque-Id" => "57ad9a65dedabdb059a582709550c19f"
        }
      },
      "response" => {
        "took" => 8,
        "timed_out" => false,
        "slice_id" => 0,
        "total" => 39,
        "updated" => 10,
        "created" => 0,
        "deleted" => 0,
        "batches" => 1,
        "version_conflicts" => 0,
        "noops" => 0,
        "retries" => {
          "bulk" => 0,
          "search" => 0
        },
        "throttled" => "0s",
        "throttled_millis" => 0,
        "requests_per_second" => -1.0,
        "throttled_until" => "0s",
        "throttled_until_millis" => 0,
        "failures" => []
      },
      "error" => {
        "type" => "search_phase_execution_exception",
        "reason" => "Partial shards failure",
        "phase" => "query",
        "grouped" => true,
        "failed_shards" => [
          {
            "shard" => 34,
            "index" => "gitlab-development-issues-20231218-1640-reindex-5-0",
            "node" => "Z0FuOiOhRwOYB2tIfOi1WQ",
            "reason" => {
              "type" => "exception",
              "reason" => "Trying to create too many scroll contexts."
            }
          }
        ]
      }
    }
  end

  let(:not_completed_response) do
    {
      "completed" => false,
      "task" => {
        "node" => "99YgTgMFRSC38-gIr1XM-A",
        "id" => 22472,
        "type" => "transport",
        "action" => "indices:data/write/reindex",
        "status" => {
          "slice_id" => 0,
          "total" => 39,
          "updated" => 39,
          "created" => 0,
          "deleted" => 0,
          "batches" => 1,
          "version_conflicts" => 0,
          "noops" => 0,
          "retries" => {
            "bulk" => 0,
            "search" => 0
          },
          "throttled_millis" => 0,
          "requests_per_second" => -1.0,
          "throttled_until_millis" => 0
        },
        "description" => "reindex from [gitlab-dev-issues-20231218] to [gitlab-dev-issues-20240105-reindex-7-0]",
        "start_time_in_millis" => 1704479577661,
        "running_time_in_nanos" => 8594250,
        "cancellable" => true,
        "cancelled" => false,
        "headers" => {}
      },
      "response" => {
        "took" => 8,
        "timed_out" => false,
        "slice_id" => 0,
        "total" => 39,
        "updated" => 39,
        "created" => 0,
        "deleted" => 0,
        "batches" => 1,
        "version_conflicts" => 0,
        "noops" => 0,
        "retries" => {
          "bulk" => 0,
          "search" => 0
        },
        "throttled" => "0s",
        "throttled_millis" => 0,
        "requests_per_second" => -1.0,
        "throttled_until" => "0s",
        "throttled_until_millis" => 0,
        "failures" => []
      }
    }
  end
end
