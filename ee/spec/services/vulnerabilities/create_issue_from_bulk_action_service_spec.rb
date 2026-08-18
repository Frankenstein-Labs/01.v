# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::CreateIssueFromBulkActionService, '#execute', feature_category: :vulnerability_management do
  let_it_be(:group)   { create(:group) }
  let_it_be(:project) { create(:project, :public, :repository, namespace: group) }
  let_it_be(:user)    { create(:user) }

  before_all do
    group.add_developer(user)
  end

  shared_examples 'a created issue' do
    let(:result) { described_class.new(project, user, params).execute }

    it 'creates the issue with the given params' do
      expect(result[:status]).to eq(:success)
      issue = result[:issue]
      expect(issue).to be_persisted
      expect(issue.project).to eq(project)
      expect(issue.author).to eq(user)
      expect(issue.title).to eq(expected_title)
      expect(issue.description).to eq(expected_description)
      expect(issue).to be_confidential
    end

    context 'when Issues::CreateService fails' do
      before do
        allow_next_instance_of(Issues::CreateService) do |create_service|
          allow(create_service).to receive(:execute).and_return(ServiceResponse.error(message: 'unexpected error'))
        end
      end

      it 'returns an error' do
        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq('unexpected error')
      end
    end
  end

  context 'when user does not have permission to create issue' do
    let(:result) { described_class.new(project, user, {}).execute }

    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:can?).with(user, :create_issue, project).and_return(false)
      end
    end

    it 'returns expected error' do
      expect(result[:status]).to eq(:error)
      expect(result[:message]).to eq("User is not permitted to create issue")
    end
  end

  context 'when issues are disabled on project' do
    let(:result) { described_class.new(project, user, {}).execute }
    let(:project) { build(:project, :public, namespace: group, issues_access_level: ProjectFeature::DISABLED) }

    it 'returns expected error' do
      expect(result).to be_error
      expect(result[:message]).to eq("User is not permitted to create issue")
    end
  end

  context 'when successful' do
    let(:title) { "Vulnerability Title" }
    let(:params) { {} }

    let(:expected_title) { "Investigate vulnerabilities" }
    let(:expected_description) { nil }

    it_behaves_like 'a created issue'

    context 'when the title of the vulnerability is longer than maximum issue title' do
      let(:max_title_length) { 255 }
      let(:title) { ('a' * max_title_length) }
      let(:expected_title) { "Investigate vulnerabilities" }

      it_behaves_like 'a created issue'
    end
  end
end
