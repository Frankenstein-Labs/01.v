# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SweBenchSeeder::IssueManager, feature_category: :duo_chat do
  let(:project) { instance_double(Project) }
  let(:user) { instance_double(User) }
  let(:issue) { instance_double(Issue, iid: 1, title: 'Fix the login bug') }
  let(:issues_relation) { double }

  describe '.create_issue_from_problem_statement' do
    let(:problem_statement) do
      "Fix the login bug\n\nThe login page is broken when using special characters in passwords."
    end

    let(:created_issue) { instance_double(Issue, iid: 1, title: 'Fix the login bug', description: 'Test') }
    let(:service_response) { ServiceResponse.success(payload: { issue: created_issue }) }

    subject(:create_issue) do
      described_class.create_issue_from_problem_statement(project, user, problem_statement)
    end

    before do
      allow(project).to receive(:issues).and_return(issues_relation)
      allow(issues_relation).to receive(:find_by_title).and_return(nil)
      allow(::Issues::CreateService).to receive(:new).and_return(instance_double(::Issues::CreateService,
        execute: service_response))
      # rubocop:disable RSpec/VerifiedDoubles -- UrlHelpers is a module, not a class
      allow(Rails.application.routes).to receive(:url_helpers).and_return(double(
        project_issue_url: 'http://example.com/issue/1'))
      # rubocop:enable RSpec/VerifiedDoubles
    end

    context 'when problem statement is valid' do
      it 'creates an issue with correct title and description' do
        expect(::Issues::CreateService).to receive(:new).with(
          container: project,
          current_user: user,
          params: hash_including(
            title: 'Fix the login bug'
          )
        ).and_return(instance_double(::Issues::CreateService, execute: service_response))

        result = create_issue

        expect(result).to eq(created_issue)
      end
    end

    context 'when problem statement is blank or nil' do
      it 'returns nil without creating an issue' do
        result = described_class.create_issue_from_problem_statement(project, user, '')
        expect(result).to be_nil

        result = described_class.create_issue_from_problem_statement(project, user, nil)
        expect(result).to be_nil
      end
    end

    context 'when an issue with the same title already exists' do
      let(:existing_issue) { instance_double(Issue, title: 'Fix the login bug') }

      before do
        allow(issues_relation).to receive(:find_by_title).with('Fix the login bug').and_return(existing_issue)
        allow(::Issues::DestroyService).to receive(:new).and_return(instance_double(::Issues::DestroyService,
          execute: true))
      end

      it 'deletes the existing issue and creates a new one' do
        expect(::Issues::DestroyService).to receive(:new).with(container: project, current_user: user)

        result = create_issue

        expect(result).to eq(created_issue)
      end
    end

    context 'when issue creation fails' do
      let(:failed_response) { ServiceResponse.error(message: 'Invalid title') }

      before do
        allow(::Issues::CreateService).to receive(:new).and_return(instance_double(::Issues::CreateService,
          execute: failed_response))
      end

      it 'returns nil' do
        result = create_issue

        expect(result).to be_nil
      end
    end

    context 'when an error occurs during issue creation' do
      before do
        allow(::Issues::CreateService).to receive(:new).and_raise(StandardError, 'Database error')
      end

      it 'lets the error propagate' do
        expect { create_issue }.to raise_error(StandardError, 'Database error')
      end
    end
  end

  describe '.destroy_instance_projects' do
    let(:subgroup) { instance_double(Group, full_path: 'test-group') }
    let(:project1) { instance_double(Project, full_path: 'test-group/project1') }
    let(:project2) { instance_double(Project, full_path: 'test-group/project2') }
    let(:mirror_project) { instance_double(Project, full_path: 'test-group/mirrors/django') }
    let(:projects_relation) { double }
    let(:destroy_service) { instance_double(::Projects::DestroyService, execute: true) }

    subject(:destroy_projects) do
      described_class.destroy_instance_projects(subgroup, user)
    end

    before do
      allow(subgroup).to receive(:all_projects).and_return(projects_relation)
      allow(projects_relation).to receive(:find_each)
        .and_yield(project1).and_yield(mirror_project).and_yield(project2)
      allow(::Projects::DestroyService).to receive(:new).and_return(destroy_service)
    end

    it 'destroys projects but skips mirrors' do
      expect(::Projects::DestroyService).to receive(:new).with(project1, user).and_return(destroy_service)
      expect(::Projects::DestroyService).to receive(:new).with(project2, user).and_return(destroy_service)
      expect(::Projects::DestroyService).not_to receive(:new).with(mirror_project, user)

      destroy_projects
    end

    it 'logs skipped mirror projects' do
      expect { destroy_projects }.to output(%r{Skipping mirror project: test-group/mirrors/django}).to_stdout
    end

    it 'handles project deletion failure' do
      allow(::Projects::DestroyService).to receive(:new).and_raise(StandardError, 'Deletion error')

      expect { destroy_projects }.to output(/Failed to delete project/).to_stdout
    end
  end
end
