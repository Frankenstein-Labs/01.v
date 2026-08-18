# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::GenerateCommitMessageService, :saas, feature_category: :code_review_workflow do
  let_it_be_with_refind(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be_with_refind(:project) { create(:project, :public, group: group) }
  let_it_be(:resource, freeze: false) { create(:merge_request, source_project: project) }

  let(:options) { {} }

  subject { described_class.new(user, resource, options) }

  before_all do
    group.namespace_settings.update!(experiment_features_enabled: true)
  end

  before do
    stub_ee_application_setting(should_check_namespace_plan: true)
    stub_licensed_features(generate_commit_message: true, ai_features: true, experimental_features: true)

    allow(user).to receive(:can?).and_call_original
    allow(user).to receive(:can?).with("read_merge_request", resource).and_call_original
    allow(user).to receive(:can?).with(:access_duo_features, resource.project).and_call_original
    allow(user).to receive(:can?).with(:admin_all_resources).and_call_original
  end

  describe '#execute' do
    before do
      allow(Llm::CompletionWorker).to receive(:perform_for)
    end

    context 'when the user is permitted to view the merge request' do
      before do
        group.add_developer(user)

        allow(user)
          .to receive(:can?)
          .with(:access_generate_commit_message, resource)
          .and_return(true)
        allow(user).to receive(:allowed_to_use?).with(:generate_commit_message).and_return(true)
      end

      it_behaves_like 'schedules completion worker' do
        let(:action_name) { :generate_commit_message }
      end

      it 'tracks the generate_merge_commit_message internal event with the derived project and namespace' do
        # Use a fresh options hash: schedule_completion_worker mutates the passed
        # options (adds :start_time), and the shared let_it_be(:options) would leak
        # that mutation into the 'schedules completion worker' example.
        expect { described_class.new(user, resource, {}).execute }
          .to trigger_internal_events('generate_merge_commit_message')
          .with(user: user, project: project)
      end
    end

    context 'when the user is not permitted to view the merge request' do
      before do
        allow(project).to receive(:member?).with(user).and_return(false)
      end

      it 'returns an error' do
        expect(subject.execute).to be_error

        expect(Llm::CompletionWorker).not_to have_received(:perform_for)
      end

      it 'does not track the generate_merge_commit_message internal event' do
        expect { subject.execute }.not_to trigger_internal_events('generate_merge_commit_message')
      end
    end
  end

  describe '#valid?' do
    using RSpec::Parameterized::TableSyntax

    where(:access_generate_commit_message, :result) do
      true   | true
      false  | false
    end

    with_them do
      subject { described_class.new(user, resource, options) }

      before do
        group.add_maintainer(user)

        allow(user)
          .to receive(:can?)
          .with(:access_generate_commit_message, resource)
          .and_return(access_generate_commit_message)
        allow(user).to receive(:allowed_to_use?).with(:generate_commit_message).and_return(true)
      end

      it { expect(subject.valid?).to eq(result) }
    end
  end
end
