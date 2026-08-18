# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::AuditLog, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }

  let(:read_project_secret_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "entity_id" => "60792534-ee8a-bdc5-6416-005af4303ac4",
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "read",
        "path" => "secrets/kv/data/explicit/my_test_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:read_project_secret_pipeline_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/pipelines/global"],
        "entity_id" => "60792534-ee8a-bdc5-6416-005af4303ac4",
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s,
                        "pipeline_id" => "12345",
                        "job_id" => "67890" }
      },
      "request" => {
        "operation" => "read",
        "path" => "secrets/kv/data/explicit/my_test_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:create_project_secret_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "entity_id" => "60792534-ee8a-bdc5-6416-005af4303ac4",
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "create",
        "path" => "secrets/kv/data/explicit/new_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:delete_project_secret_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "entity_id" => "60792534-ee8a-bdc5-6416-005af4303ac4",
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "delete",
        "path" => "secrets/kv/metadata/explicit/deleted_secret",
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_project_secret_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "update",
        "path" => "secrets/kv/metadata/explicit/my_test_secret",
        "data" => {
          "custom_metadata" => {
            "branch" => "main",
            "create_completed_at" => "2025-09-27T15:01:20Z",
            "description" => "Updated description",
            "environment" => "*",
            "update_started_at" => "2025-09-27T15:01:27Z",
            "update_completed_at" => "2025-09-27T15:01:27Z"
          },
          "metadata_cas" => 2
        },
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_project_secret_request_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "request",
      "auth" => {
        "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
        "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                        "namespace_id" => project.namespace.id.to_s,
                        "project_id" => project.id.to_s,
                        "user_id" => user.id.to_s }
      },
      "request" => {
        "operation" => "update",
        "path" => "secrets/kv/metadata/explicit/my_test_secret",
        "data" => {
          "custom_metadata" => {
            "description" => "Updated description",
            "environment" => "*",
            "update_started_at" => "2025-09-27T15:01:27Z",
            "update_completed_at" => "2025-09-27T15:01:27Z"
          },
          "metadata_cas" => 2
        },
        "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:read_group_secret_log_json) do
    {
      "time" => "2026-01-12T15:10:16.613438Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}", "users/roles/50"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESC3ZDGGZSSD1S1YXESC802",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "read",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORDDS",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:read_group_secret_pipeline_log_json) do
    {
      "time" => "2026-01-12T15:10:16.613438Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "group_#{group.id}/pipelines/combined/unprotected/global"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESC3ZDGGZSSD1S1YXESC802",
          "group_id" => group.id.to_s,
          "project_id" => "999",
          "user_id" => user.id.to_s,
          "pipeline_id" => "12345",
          "job_id" => "67890"
        }
      },
      "request" => {
        "operation" => "read",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORDDS",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:create_group_secret_log_json) do
    {
      "time" => "2026-01-12T14:51:57.787927Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}", "users/roles/50"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESB2EA5HPDQHBHVQQ0ZZ93D",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "create",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORD",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:delete_group_secret_log_json) do
    {
      "time" => "2026-01-12T14:52:00.123456Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESB2EA5HPDQHBHVQQ0ZZ93D",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "delete",
        "path" => "secrets/kv/metadata/explicit/DATABASE_PASSWORD",
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_group_secret_log_json) do
    {
      "time" => "2026-01-12T15:10:27.457384Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}", "users/roles/50"],
        "metadata" => {
          "correlation_id" => "01KESC49YJ5HFYX8S68H2EF79T",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "update",
        "path" => "secrets/kv/metadata/explicit/DATABASE_PASSWORDDS",
        "data" => {
          "custom_metadata" => {
            "create_completed_at" => "2026-01-12T15:10:20Z",
            "description" => "Updated description",
            "environment" => "*",
            "protected" => "false",
            "update_started_at" => "2026-01-12T15:10:27Z",
            "update_completed_at" => "2026-01-12T15:10:27Z"
          },
          "metadata_cas" => 2
        },
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:update_group_secret_request_log_json) do
    {
      "time" => "2026-01-12T15:10:27.457184Z",
      "type" => "request",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{group.id}"],
        "metadata" => {
          "correlation_id" => "01KESC49YJ5HFYX8S68H2EF79T",
          "group_id" => group.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "update",
        "path" => "secrets/kv/metadata/explicit/DATABASE_PASSWORDDS",
        "data" => {
          "custom_metadata" => {
            "description" => "Updated description",
            "environment" => "*",
            "protected" => "false",
            "update_started_at" => "2026-01-12T15:10:27Z",
            "update_completed_at" => "2026-01-12T15:10:27Z"
          },
          "metadata_cas" => 2
        },
        "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:create_subgroup_secret_log_json) do
    {
      "time" => "2026-01-12T14:51:57.787927Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default", "users/direct/group_#{subgroup.id}", "users/direct/user_#{user.id}"],
        "entity_id" => "84aa64f5-0f23-0b5a-fc13-cbb993bacd7b.GQbQLT",
        "metadata" => {
          "correlation_id" => "01KESB2EA5HPDQHBHVQQ0ZZ93D",
          "group_id" => subgroup.id.to_s,
          "organization_id" => "1",
          "root_group_id" => group.id.to_s,
          "user_id" => user.id.to_s
        }
      },
      "request" => {
        "operation" => "create",
        "path" => "secrets/kv/data/explicit/DATABASE_PASSWORD",
        "namespace" => { "id" => "GQbQLT", "path" => "org_1/group_#{group.id}/group_#{subgroup.id}/" },
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:unknown_event_log_json) do
    {
      "time" => "2025-09-27T15:01:27.13058Z",
      "type" => "response",
      "auth" => {
        "policies" => ["default"]
      },
      "request" => {
        "operation" => "list",
        "path" => "sys/auth",
        "remote_address" => "172.16.123.1"
      },
      "response" => {
        "mount_type" => "kv"
      }
    }.to_json
  end

  let(:invalid_json) { "invalid json content" }
  let(:non_existing_project_id) { non_existing_record_id }
  let(:non_existing_group_id) { non_existing_record_id }

  before_all do
    project.add_owner(user)
    group.add_owner(user)
  end

  describe '#initialize' do
    it 'sets raw_audit_log_json and initializes attributes' do
      audit_log = described_class.new(update_project_secret_log_json)

      expect(audit_log.raw_audit_log_json).to eq(update_project_secret_log_json)
      expect(audit_log.project).to eq(project)
      expect(audit_log.event_type).to eq(:secrets_manager_update_project_secret)
      expect(audit_log.author).to eq(user)
      expect(audit_log.ip_address).to eq("172.16.123.1")
    end

    it 'extracts pipeline_id and job_id from pipeline token metadata' do
      audit_log = described_class.new(read_project_secret_pipeline_log_json)

      expect(audit_log.pipeline_id).to eq("12345")
      expect(audit_log.job_id).to eq("67890")
    end

    it 'sets pipeline_id and job_id to nil when not present in metadata' do
      audit_log = described_class.new(update_project_secret_log_json)

      expect(audit_log.pipeline_id).to be_nil
      expect(audit_log.job_id).to be_nil
    end

    it 'handles invalid JSON gracefully' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(JSON::ParserError))

      audit_log = described_class.new(invalid_json)

      expect(audit_log.raw_audit_log_json).to eq(invalid_json)
    end
  end

  describe '#target_details' do
    it 'includes the project path for project secret events' do
      audit_log = described_class.new(update_project_secret_log_json)

      expect(audit_log.target_details).to eq("Project: #{project.full_path}")
    end

    it 'includes the group path for group secret events' do
      audit_log = described_class.new(read_group_secret_log_json)

      expect(audit_log.target_details).to eq("Group: #{group.full_path}")
    end

    it 'returns an empty project path when the project is missing' do
      payload = Gitlab::Json.safe_parse(read_project_secret_log_json)
      payload["auth"]["metadata"]["project_id"] = non_existing_project_id.to_s
      audit_log = described_class.new(payload.to_json)

      expect(audit_log.target_details).to eq("Project: ")
    end

    it 'returns an empty group path when the group is missing' do
      payload = Gitlab::Json.safe_parse(read_group_secret_log_json)
      payload["auth"]["metadata"]["group_id"] = non_existing_group_id.to_s
      audit_log = described_class.new(payload.to_json)

      expect(audit_log.target_details).to eq("Group: ")
    end
  end

  describe '#log!' do
    context 'when audit should be logged' do
      it 'calls Gitlab::Audit::Auditor.audit with correct context' do
        audit_log = described_class.new(update_project_secret_log_json)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: :secrets_manager_update_project_secret,
            author: user,
            scope: project,
            target: project,
            message: "Updated project secret",
            ip_address: "172.16.123.1",
            additional_details: { raw_audit_log_json: update_project_secret_log_json },
            target_details: "Project: #{project.full_path}"
          )
        ).and_call_original

        expect(audit_log.log!).to be_truthy
      end
    end

    context 'when runtime error occurs during logging' do
      it 'propagates the error so async callers can retry' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(ActiveRecord::RecordNotFound)

        audit_log = described_class.new(update_project_secret_log_json)

        expect { audit_log.log! }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when pipeline reads a project secret' do
      it 'includes pipeline_id and job_id in additional_details' do
        audit_log = described_class.new(read_project_secret_pipeline_log_json)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              pipeline_id: "12345",
              job_id: "67890"
            )
          )
        ).and_call_original

        audit_log.log!
      end
    end

    context 'when pipeline reads a group secret' do
      it 'includes pipeline_id and job_id in additional_details' do
        audit_log = described_class.new(read_group_secret_pipeline_log_json)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              pipeline_id: "12345",
              job_id: "67890"
            )
          )
        ).and_call_original

        audit_log.log!
      end
    end

    context 'when audit should not be logged' do
      it 'does not call Gitlab::Audit::Auditor.audit for project secret request logs' do
        audit_log = described_class.new(update_project_secret_request_log_json)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit_log.log!
      end

      it 'does not call Gitlab::Audit::Auditor.audit for group secret request logs' do
        audit_log = described_class.new(update_group_secret_request_log_json)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit_log.log!
      end

      it 'does not call Gitlab::Audit::Auditor.audit for unknown events' do
        audit_log = described_class.new(unknown_event_log_json)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        audit_log.log!
      end
    end
  end

  describe 'project secret operations' do
    using RSpec::Parameterized::TableSyntax

    where(:operation, :log_json_method, :expected_event_type, :expected_message) do
      'read'   | :read_project_secret_log_json    | :secrets_manager_read_project_secret   | "Read project secret"
      'create' | :create_project_secret_log_json  | :secrets_manager_create_project_secret | "Created project secret"
      'update' | :update_project_secret_log_json  | :secrets_manager_update_project_secret | "Updated project secret"
      'delete' | :delete_project_secret_log_json  | :secrets_manager_delete_project_secret | "Deleted project secret"
    end

    with_them do
      let(:audit_log) { described_class.new(public_send(log_json_method)) }

      describe 'audit event attributes' do
        it 'returns correct event type' do
          expect(audit_log.event_type).to eq(expected_event_type)
        end

        it 'returns correct message' do
          expect(audit_log.message).to eq(expected_message)
        end

        it 'extracts correct author' do
          expect(audit_log.author).to eq(user)
        end

        it 'extracts correct project' do
          expect(audit_log.project).to eq(project)
        end
      end
    end
  end

  describe 'group secret operations' do
    using RSpec::Parameterized::TableSyntax

    where(:operation, :log_json_method, :expected_event_type, :expected_message) do
      'read'   | :read_group_secret_log_json    | :secrets_manager_read_group_secret   | "Read group secret"
      'create' | :create_group_secret_log_json  | :secrets_manager_create_group_secret | "Created group secret"
      'update' | :update_group_secret_log_json  | :secrets_manager_update_group_secret | "Updated group secret"
      'delete' | :delete_group_secret_log_json  | :secrets_manager_delete_group_secret | "Deleted group secret"
    end

    with_them do
      let(:audit_log) { described_class.new(public_send(log_json_method)) }

      describe 'audit event attributes' do
        it 'returns correct event type' do
          expect(audit_log.event_type).to eq(expected_event_type)
        end

        it 'returns correct message' do
          expect(audit_log.message).to eq(expected_message)
        end

        it 'extracts correct author' do
          expect(audit_log.author).to eq(user)
        end

        it 'extracts correct group' do
          expect(audit_log.group).to eq(group)
        end
      end
    end
  end

  describe 'metadata-based scope classification' do
    it 'classifies as a group event when metadata carries group_id', :aggregate_failures do
      audit_log = described_class.new(create_group_secret_log_json)

      expect(audit_log.event_type).to eq(:secrets_manager_create_group_secret)
      expect(audit_log.group).to eq(group)
      expect(audit_log.project).to be_nil
    end

    it 'classifies as a project event when metadata carries project_id without group_id', :aggregate_failures do
      audit_log = described_class.new(create_project_secret_log_json)

      expect(audit_log.event_type).to eq(:secrets_manager_create_project_secret)
      expect(audit_log.project).to eq(project)
      expect(audit_log.group).to be_nil
    end

    it 'classifies a pipeline read with both ids as a group event', :aggregate_failures do
      audit_log = described_class.new(read_group_secret_pipeline_log_json)

      expect(audit_log.event_type).to eq(:secrets_manager_read_group_secret)
      expect(audit_log.group).to eq(group)
      expect(audit_log.project).to be_nil
    end
  end

  describe 'subgroup group secret' do
    it 'resolves the subgroup and emits the audit event from metadata', :aggregate_failures do
      audit_log = described_class.new(create_subgroup_secret_log_json)

      expect(audit_log.event_type).to eq(:secrets_manager_create_group_secret)
      expect(audit_log.group).to eq(subgroup)

      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: :secrets_manager_create_group_secret,
          scope: subgroup,
          target: subgroup,
          target_details: "Group: #{subgroup.full_path}"
        )
      ).and_call_original

      expect(audit_log.log!).to be_truthy
    end
  end

  # Create and update both hit the secret metadata path with `update` ops, and an update touches it
  # twice. Only the completed write of a real update (carrying update_completed_at) is an update
  # event - everything else on that path is bookkeeping. Without this a create would log a phantom
  # update and a single update would be audited twice.
  describe 'update event deduplication' do
    # A secret update writes the metadata path twice; this is the in-flight write (no
    # update_completed_at), which must not be audited so a single update isn't logged twice.
    let(:update_in_progress_project_secret_log_json) do
      {
        "time" => "2025-09-27T15:01:27.13058Z",
        "type" => "response",
        "auth" => {
          "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
          "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                          "namespace_id" => project.namespace.id.to_s,
                          "project_id" => project.id.to_s,
                          "user_id" => user.id.to_s }
        },
        "request" => {
          "operation" => "update",
          "path" => "secrets/kv/metadata/explicit/my_test_secret",
          "data" => {
            "custom_metadata" => {
              "branch" => "main",
              "create_completed_at" => "2025-09-27T15:01:20Z",
              "description" => "Updated description",
              "environment" => "*",
              "update_started_at" => "2025-09-27T15:01:27Z"
            },
            "metadata_cas" => 1
          },
          "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
          "remote_address" => "172.16.123.1"
        },
        "response" => {
          "mount_type" => "kv"
        }
      }.to_json
    end

    # The metadata write a create performs (an `update` op on the metadata path) must not be
    # mistaken for an update event - it never carries update_completed_at.
    let(:create_metadata_write_project_secret_log_json) do
      {
        "time" => "2025-09-27T15:01:27.13058Z",
        "type" => "response",
        "auth" => {
          "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
          "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                          "namespace_id" => project.namespace.id.to_s,
                          "project_id" => project.id.to_s,
                          "user_id" => user.id.to_s }
        },
        "request" => {
          "operation" => "update",
          "path" => "secrets/kv/metadata/explicit/new_secret",
          "data" => {
            "custom_metadata" => {
              "branch" => "main",
              "create_completed_at" => "2025-09-27T15:01:27Z",
              "description" => "Created for audit test",
              "environment" => "*"
            },
            "metadata_cas" => 1
          },
          "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
          "remote_address" => "172.16.123.1"
        },
        "response" => {
          "mount_type" => "kv"
        }
      }.to_json
    end

    # A value update writes the data path as an `update` op; the audit event comes from the paired
    # completed metadata write, so this data write must not be audited (avoids double logging).
    let(:update_value_data_write_project_secret_log_json) do
      {
        "time" => "2025-09-27T15:01:27.13058Z",
        "type" => "response",
        "auth" => {
          "policies" => ["default", "project_#{project.id}/users/direct/user_#{user.id}"],
          "metadata" => { "correlation_id" => "01K7KVMBNNDJK2YVC729B5ERF0",
                          "namespace_id" => project.namespace.id.to_s,
                          "project_id" => project.id.to_s,
                          "user_id" => user.id.to_s }
        },
        "request" => {
          "operation" => "update",
          "path" => "secrets/kv/data/explicit/my_test_secret",
          "namespace" => { "id" => "M0zDLE", "path" => "user_#{user.id}/project_#{project.id}" },
          "remote_address" => "172.16.123.1"
        },
        "response" => {
          "mount_type" => "kv"
        }
      }.to_json
    end

    # Group counterpart of the create metadata write - an `update` op without update_completed_at.
    let(:create_metadata_write_group_secret_log_json) do
      {
        "time" => "2026-01-12T14:51:57.787927Z",
        "type" => "response",
        "auth" => {
          "policies" => ["default", "users/direct/group_#{group.id}", "users/direct/user_#{user.id}"],
          "metadata" => {
            "correlation_id" => "01KESB2EA5HPDQHBHVQQ0ZZ93D",
            "group_id" => group.id.to_s,
            "organization_id" => "1",
            "root_group_id" => group.id.to_s,
            "user_id" => user.id.to_s
          }
        },
        "request" => {
          "operation" => "update",
          "path" => "secrets/kv/metadata/explicit/DATABASE_PASSWORD",
          "data" => {
            "custom_metadata" => {
              "create_completed_at" => "2026-01-12T14:51:57Z",
              "description" => "Created for audit test",
              "environment" => "*",
              "protected" => "false"
            },
            "metadata_cas" => 1
          },
          "namespace" => { "id" => "GQbQLT", "path" => "group_#{group.id}/group_#{group.id}/" },
          "remote_address" => "172.16.123.1"
        },
        "response" => {
          "mount_type" => "kv"
        }
      }.to_json
    end

    it 'audits the completed metadata write of an update exactly once', :aggregate_failures do
      expect(described_class.new(update_project_secret_log_json).event_type)
        .to eq(:secrets_manager_update_project_secret)
      expect(described_class.new(update_group_secret_log_json).event_type)
        .to eq(:secrets_manager_update_group_secret)
    end

    it 'ignores an update in-flight metadata write that has no update_completed_at' do
      expect(described_class.new(update_in_progress_project_secret_log_json).event_type)
        .to eq(:unknown_event)
    end

    it 'ignores the metadata write performed during a create', :aggregate_failures do
      expect(described_class.new(create_metadata_write_project_secret_log_json).event_type)
        .to eq(:unknown_event)
      expect(described_class.new(create_metadata_write_group_secret_log_json).event_type)
        .to eq(:unknown_event)
    end

    it 'ignores the data write of a value update so it is not double counted' do
      expect(described_class.new(update_value_data_write_project_secret_log_json).event_type)
        .to eq(:unknown_event)
    end

    it 'does not call the auditor for noise metadata writes', :aggregate_failures do
      expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

      described_class.new(update_in_progress_project_secret_log_json).log!
      described_class.new(create_metadata_write_project_secret_log_json).log!
      described_class.new(create_metadata_write_group_secret_log_json).log!
      described_class.new(update_value_data_write_project_secret_log_json).log!
    end
  end
end
