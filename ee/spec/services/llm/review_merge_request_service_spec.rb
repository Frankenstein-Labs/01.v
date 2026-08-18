# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::ReviewMergeRequestService, :saas, feature_category: :duo_code_review do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:resource) { create(:merge_request, source_project: project, target_project: project, author: user) }
  let_it_be(:duo_code_review_bot) { Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

  let(:ai_review_merge_request_allowed?) { true }
  let(:current_user) { user }
  let(:options) { {} }

  describe '#perform' do
    include_context 'with ai features enabled for group'

    let(:action_name) { :review_merge_request }
    let(:content) { 'Review merge request' }

    before_all do
      group.add_guest(user)
    end

    before do
      allow(resource)
        .to receive(:ai_review_merge_request_allowed?)
        .with(user)
        .and_return(ai_review_merge_request_allowed?)
      allow(user).to receive(:allowed_to_use?).with(:review_merge_request).and_return(true)
    end

    subject { described_class.new(current_user, resource, options).execute }

    it_behaves_like 'schedules completion worker' do
      let(:note) { instance_double(Note, id: 123) }

      before do
        allow_next_instance_of(
          ::SystemNotes::MergeRequestsService,
          noteable: resource,
          container: project,
          author: duo_code_review_bot
        ) do |system_note_service|
          allow(system_note_service).to receive(:duo_code_review_started).and_return(note)
        end
      end

      let(:expected_options) { { progress_note_id: note.id } }

      subject { described_class.new(current_user, resource, options) }
    end

    context 'when user is not member of project group' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when resource is not a merge_request' do
      let(:resource) { create(:epic, group: group) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when user has no ability to ai_review_merge_request' do
      let(:ai_review_merge_request_allowed?) { false }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when the current user is the MR author' do
      it_behaves_like 'internal event tracking' do
        let(:event) { 'request_review_duo_code_review_on_mr_by_author' }
        let(:category) { described_class.name }
        let(:namespace) { nil }
        let(:project) { resource.project }

        subject(:track_event) { described_class.new(user, resource, options).execute }
      end
    end

    context 'when the current user is not the MR author' do
      let_it_be(:non_author_user) { create(:user) }
      let(:progress_note) { instance_double(Note, id: 123) }
      let(:service) { described_class.new(non_author_user, resource, options) }

      before_all do
        group.add_guest(non_author_user)
      end

      before do
        allow(non_author_user).to receive(:allowed_to_use?).with(:review_merge_request).and_return(true)
        allow(resource)
          .to receive(:ai_review_merge_request_allowed?)
          .with(non_author_user)
          .and_return(true)
      end

      it 'tracks the non-author event' do
        expect { service.execute }
          .to trigger_internal_events('request_review_duo_code_review_on_mr_by_non_author')
          .with(user: non_author_user, project: resource.project)
          .and increment_usage_metrics('counts.count_total_request_review_duo_code_review_on_mr_by_non_author')
      end
    end
  end
end
