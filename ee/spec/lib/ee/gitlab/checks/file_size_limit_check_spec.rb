# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::FileSizeLimitCheck, feature_category: :source_code_management do
  include_context 'changes access checks context'
  include_context 'push rules checks context'

  let(:changes) do
    [
      # Update of existing branch
      { oldrev: oldrev, newrev: newrev, ref: ref },
      # Creation of new branch
      { newrev: newrev, ref: 'refs/heads/something' },
      # Deletion of branch
      { oldrev: oldrev, ref: 'refs/heads/deleteme' }
    ]
  end

  let(:changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: push_options,
      gitaly_context: gitaly_context
    )
  end

  let(:push_rule_limit) { 50 }
  let(:push_rule) { create(:push_rule, max_file_size: push_rule_limit) }
  let(:global_limit) { 10 }
  let(:plan_limits) { instance_double(PlanLimits, file_size_limit_mb: global_limit) }

  before do
    allow(project).to receive_messages(
      predefined_push_rule: push_rule,
      actual_limits: plan_limits
    )
  end

  subject(:file_size_check) { described_class.new(changes_access) }

  RSpec.shared_examples 'checks file size limit' do |expected_limit|
    it "passes the correct file size limit to HookEnvironmentAwareAnyOversizedBlobs" do
      expect_next_instance_of(Gitlab::Checks::FileSizeCheck::HookEnvironmentAwareAnyOversizedBlobs,
        project: project,
        changes: changes,
        file_size_limit_megabytes: expected_limit
      ) do |check|
        expect(check).to receive(:find).and_call_original
      end
      file_size_check.validate!
    end
  end

  describe '#validate!' do
    describe 'when self-managed (global limit ignored)' do
      before do
        stub_saas_features(instance_push_limit: false)
      end

      let(:push_rule_limit) { 50 }
      let(:global_limit) { 20 }

      it_behaves_like 'checks file size limit', 50
    end

    context 'when on Saas' do
      before do
        stub_saas_features(instance_push_limit: true)
      end

      where(:push_rule_limit, :global_limit, :expected_limit) do
        [
          [50, 20, 20],
          [10, 50, 10],
          [30, nil, 30],
          [0, 20, 20]
        ]
      end

      with_them do
        it "passes the correct file size limit to HookEnvironmentAwareAnyOversizedBlobs" do
          expect_next_instance_of(Gitlab::Checks::FileSizeCheck::HookEnvironmentAwareAnyOversizedBlobs,
            project: project,
            changes: changes,
            file_size_limit_megabytes: expected_limit
          ) do |check|
            expect(check).to receive(:find).and_call_original
          end
          file_size_check.validate!
        end
      end

      context 'when the push rule does not exist' do
        let(:push_rule) { nil }
        let(:global_limit) { 50 }

        it_behaves_like 'checks file size limit', 50
      end

      context 'when source is push_rule and the file exceeds the limit' do
        let(:push_rule_limit) { 2 }
        let(:global_limit) { 50 }
        let(:mock_blob_id) { "88acbfafb1b8fdb7c51db870babce21bd861ac4f" }
        let(:mock_blob_size) { 300 * 1024 * 1024 } # 300 MiB
        let(:blob_double) { instance_double(Gitlab::Git::Blob, size: mock_blob_size, id: mock_blob_id) }

        before do
          stub_saas_features(instance_push_limit: true)
          allow_next_instance_of(Gitlab::Checks::FileSizeCheck::HookEnvironmentAwareAnyOversizedBlobs,
            project: project,
            changes: changes,
            file_size_limit_megabytes: push_rule_limit
          ) do |check|
            allow(check).to receive(:find).and_return([blob_double])
          end
        end

        it 'returns the correct link to the documentation in the error message' do
          expect { file_size_check.validate! }
            .to raise_exception(Gitlab::GitAccess::ForbiddenError) do |error|
              message = error.message

              expect(message).to include("push_rules/#validate-files")
              expect(message).not_to include("free_push_limit.md")
              expect(message).not_to include("account_and_limit_settings.md")
            end
        end
      end
    end
  end
end
