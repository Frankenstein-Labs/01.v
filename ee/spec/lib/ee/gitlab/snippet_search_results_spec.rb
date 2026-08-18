# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SnippetSearchResults, :with_current_organization, feature_category: :global_search do
  before do
    allow(Gitlab).to receive(:com?).and_return(com_value)
  end

  let_it_be(:snippet) { create(:project_snippet, title: 'foo', description: 'foo') }

  let(:user) { snippet.author }
  let(:com_value) { true }

  subject(:snippet_titles) do
    described_class.new(user, 'foo', organization_id: current_organization.id).objects('snippet_titles')
  end

  context 'when all requirements are met' do
    it 'calls the finder with the restrictive scope' do
      expect(SnippetsFinder).to receive(:new).with(
        user,
        { authorized_and_user_personal: true, organization_id: current_organization.id }
      ).and_call_original

      snippet_titles
    end
  end

  context 'when not in Gitlab.com' do
    let(:com_value) { false }

    it 'calls the finder with the restrictive scope' do
      expect(SnippetsFinder).to receive(:new).with(
        user,
        { organization_id: current_organization.id }
      ).and_call_original

      snippet_titles
    end
  end
end
