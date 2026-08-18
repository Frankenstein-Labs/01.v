# frozen_string_literal: true

require "spec_helper"

RSpec.describe MergeRequestResetApprovalsWorker, feature_category: :source_code_management do
  include RepoHelpers

  let(:project) { create(:project) }
  let(:user) { create(:user) }

  subject { described_class.new }

  describe "#perform" do
    let(:newrev) { "789012" }
    let(:ref)    { "refs/heads/test" }

    def perform
      subject.perform(project.id, user.id, ref, newrev)
    end

    it "executes MergeRequests::RefreshService with expected values" do
      expect_next_instance_of(MergeRequests::ResetApprovalsService, project: project, current_user: user) do |refresh_service|
        expect(refresh_service).to receive(:execute).with(ref, newrev, oldrev: nil)
      end

      perform
    end

    context 'when oldrev is provided' do
      let(:oldrev) { "abc123" }

      def perform_with_oldrev
        subject.perform(project.id, user.id, ref, newrev, oldrev)
      end

      it 'forwards oldrev to the service' do
        expect_next_instance_of(MergeRequests::ResetApprovalsService, project: project, current_user: user) do |refresh_service|
          expect(refresh_service).to receive(:execute).with(ref, newrev, oldrev: oldrev)
        end

        perform_with_oldrev
      end
    end

    context "project is missing" do
      let(:project) { double("project", id: "foo") }

      it "doesn't execute the service" do
        expect(MergeRequests::ResetApprovalsService).not_to receive(:new)

        perform
      end
    end

    context "user is missing" do
      let(:user) { double("user", id: "foo") }

      it "doesn't execute the service" do
        expect(MergeRequests::ResetApprovalsService).not_to receive(:new)

        perform
      end
    end

    context 'duration logging' do
      let(:worker) { described_class.new }
      let(:duration_stats) do
        {
          delete_code_owner_approvals_total_duration_s: 0.123,
          find_approved_code_owner_rules_total_duration_s: 0.045,
          code_owner_approver_ids_to_delete_total_duration_s: 0.067
        }
      end

      it 'logs duration statistics to done metadata when service returns hash' do
        allow_next_instance_of(MergeRequests::ResetApprovalsService) do |service|
          allow(service).to receive(:execute).and_return(duration_stats)
        end

        expect(worker).to receive(:log_hash_metadata_on_done).with(
          hash_including(
            delete_code_owner_approvals_total_duration_s: be_a(Float),
            find_approved_code_owner_rules_total_duration_s: be_a(Float),
            code_owner_approver_ids_to_delete_total_duration_s: be_a(Float),
            reset_approvals_service_total_duration_s: be_a(Float)
          )
        )

        worker.perform(project.id, user.id, ref, newrev)
      end

      it 'calculates total duration correctly' do
        allow_next_instance_of(MergeRequests::ResetApprovalsService) do |service|
          allow(service).to receive(:execute).and_return(duration_stats)
        end

        expect(worker).to receive(:log_hash_metadata_on_done) do |log_data|
          expect(log_data[:reset_approvals_service_total_duration_s]).to eq(
            log_data.except(:reset_approvals_service_total_duration_s).values.sum
          )
        end

        worker.perform(project.id, user.id, ref, newrev)
      end

      it 'rounds all durations to correct precision' do
        allow_next_instance_of(MergeRequests::ResetApprovalsService) do |service|
          allow(service).to receive(:execute).and_return(duration_stats)
        end

        expect(worker).to receive(:log_hash_metadata_on_done) do |log_data|
          log_data.each_value do |duration|
            expect(duration).to be_a(Float)
            decimal_places = duration.to_s.include?('.') ? duration.to_s.split('.').last.length : 0
            expect(decimal_places).to be <= Gitlab::InstrumentationHelper::DURATION_PRECISION
          end
        end

        worker.perform(project.id, user.id, ref, newrev)
      end

      it 'does not log when service returns nil' do
        allow_next_instance_of(MergeRequests::ResetApprovalsService) do |service|
          allow(service).to receive(:execute).and_return(nil)
        end

        expect(worker).not_to receive(:log_hash_metadata_on_done)

        worker.perform(project.id, user.id, ref, newrev)
      end
    end
  end
end
