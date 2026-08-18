# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::RapidDiffs::MergeRequestPresenter, feature_category: :code_review_workflow do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, :repository, group: group) }
  let_it_be(:current_user) { build_stubbed(:user) }
  let_it_be(:merge_request) { build_stubbed(:merge_request, source_project: project) }

  let(:can_create_project_replies) { true }
  let(:can_create_group_replies) { true }

  subject(:presenter) do
    described_class.new(merge_request, diff_view: :inline, diff_options: {},
      request_params: {}, current_user: current_user)
  end

  before do
    allow(presenter).to receive(:can?).and_call_original
    allow(presenter).to receive(:can?)
      .with(current_user, :create_saved_replies, kind_of(Project)).and_return(can_create_project_replies)
    allow(presenter).to receive(:can?)
      .with(current_user, :create_saved_replies, kind_of(Group)).and_return(can_create_group_replies)
  end

  describe '#new_comment_template_paths' do
    subject(:paths) { presenter.new_comment_template_paths }

    it 'includes user, project, and group comment template entries' do
      expect(paths).to contain_exactly(
        { text: 'Your comment templates', href: '/-/profile/comment_templates' },
        { text: 'Project comment templates', href: "/#{project.full_path}/-/comment_templates" },
        { text: 'Group comment templates', href: "/groups/#{group.full_path}/-/comment_templates" }
      )
    end

    context 'when user cannot create project saved replies' do
      let(:can_create_project_replies) { false }

      it 'omits the project entry' do
        expect(paths.pluck(:text)).not_to include('Project comment templates')
      end
    end

    context 'when user cannot create group saved replies' do
      let(:can_create_group_replies) { false }

      it 'omits the group entry' do
        expect(paths.pluck(:text)).not_to include('Group comment templates')
      end
    end

    context 'when project has no group' do
      let(:project) { build_stubbed(:project, :repository) }
      let(:merge_request) { build_stubbed(:merge_request, source_project: project) }

      it 'omits the group entry' do
        expect(paths.pluck(:text)).not_to include('Group comment templates')
      end
    end
  end
end
