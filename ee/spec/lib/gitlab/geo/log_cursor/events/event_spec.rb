# frozen_string_literal: true

require "spec_helper"

RSpec.describe Gitlab::Geo::LogCursor::Events::Event,
  :clean_gitlab_redis_shared_state,
  feature_category: :geo_replication do
  include EE::GeoHelpers

  let(:logger) { Gitlab::Geo::LogCursor::Logger.new(described_class, Logger::INFO) }
  let(:event) { create(:geo_event, :package_file, event_name: "created") }
  let(:event_log) { create(:geo_event_log, geo_event: event) }
  let(:replicable) { Packages::PackageFile.find(event.payload["model_record_id"]) }
  let!(:event_log_state) { create(:geo_event_log_state, event_id: event_log.id - 1) }

  subject(:geo_event_processor) { described_class.new(event, Time.now, logger) }

  describe "#process" do
    it "enqueues Geo::EventWorker" do
      expect(::Geo::EventWorker).to receive(:perform_async).with(
        "package_file",
        "created",
        {
          "model_record_id" => replicable.id,
          "correlation_id" => an_instance_of(String)
        }
      )

      geo_event_processor.process
    end

    it "eventually calls Replicator#consume", :sidekiq_inline do
      expect_next_instance_of(::Geo::PackageFileReplicator) do |replicator|
        expect(replicator).to receive(:consume).with(
          :created,
          {
            model_record_id: replicable.id,
            correlation_id: a_kind_of(String)
          }
        )
      end

      geo_event_processor.process
    end

    context "when deciding whether to skip enqueue for object storage events" do
      using RSpec::Parameterized::TableSyntax

      # Overrides the outer let! so it doesn't force `event` (and the object storage factory
      # it depends on) to evaluate before the object storage stub below is in place.
      let(:event_log_state) { nil }

      let(:remote_id) { create(:package_file, :pom, :object_storage).id }
      let(:local_id) { create(:package_file, :pom).id }
      let_it_be(:project_id) { create(:project).id }

      let(:event) do
        create(:geo_event, replicable_name: replicable_name, event_name: event_name,
          payload: {
            "model_record_id" => model_record_id,
            "correlation_id" => Labkit::Correlation::CorrelationId.current_or_new_id
          })
      end

      where(:sync_object_storage, :event_name, :replicable_name, :model_record_id, :enqueues) do
        true  | "created" | "package_file"       | ref(:remote_id)        | true
        false | "deleted" | "package_file"       | ref(:remote_id)        | true
        false | "created" | "project_repository" | ref(:project_id)       | true
        false | "created" | "package_file"       | ref(:remote_id)        | false
        false | "created" | "package_file"       | ref(:local_id)         | true
        false | "created" | "nonexistent"        | non_existing_record_id | false
        false | "created" | "package_file"       | nil                    | true
      end

      with_them do
        before do
          stub_package_file_object_storage(enabled: true)
          stub_current_geo_node(create(:geo_node, :secondary, sync_object_storage: sync_object_storage))
        end

        it "enqueues or skips Geo::EventWorker as expected" do
          if enqueues
            expect(::Geo::EventWorker).to receive(:perform_async)
          else
            expect(::Geo::EventWorker).not_to receive(:perform_async)
          end

          geo_event_processor.process
        end
      end

      context "when the replicable is partitioned and the payload carries the partition key" do
        let_it_be(:artifact) { create(:ci_job_artifact) }

        let(:event) do
          create(:geo_event, replicable_name: "job_artifact", event_name: "created",
            payload: {
              "model_record_id" => artifact.id,
              "partition_id" => artifact.partition_id,
              "correlation_id" => Labkit::Correlation::CorrelationId.current_or_new_id
            })
        end

        before do
          stub_current_geo_node(create(:geo_node, :secondary, sync_object_storage: false))
        end

        it "scopes the locality check by the partition key read from the payload" do
          expect(Ci::JobArtifact).to receive(:object_storage_scope_for)
            .with(anything, artifact.id, model_type: nil, partition_id: artifact.partition_id)
            .and_call_original

          geo_event_processor.process
        end
      end
    end
  end
end
