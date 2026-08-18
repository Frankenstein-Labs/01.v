# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "search/results/_error", feature_category: :global_search do
  let(:scope) { 'blobs' }
  let(:search_service) { instance_double(SearchService) }
  let(:search_results) { instance_double(::Gitlab::Elastic::SearchResults) }

  before do
    assign(:scope, scope)
    assign(:search_results, search_results)
    allow(view).to receive_messages(search_service: search_service,
      help_page_path: '/help/user/search/exact_code_search.md#syntax')
  end

  it 'renders the Pajamas::EmptyStateComponent with correct title' do
    allow(search_results).to receive(:respond_to?).with(:error).and_return(false)
    allow(search_service).to receive_messages(search_type: 'basic', use_zoekt?: false)

    render

    expect(rendered).to have_content('A problem has occurred')
  end

  context 'when search_results does not have an error method' do
    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(false)
      allow(search_service).to receive_messages(search_type: 'basic', use_zoekt?: false)
    end

    it 'displays the default error message' do
      render

      expect(rendered).to have_content('To resolve the problem, check the query syntax and try again.')
    end
  end

  context 'when search_results.error returns nil' do
    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(true)
      allow(search_results).to receive(:error).with(scope).and_return(nil)
      allow(search_service).to receive_messages(search_type: 'basic', use_zoekt?: false)
    end

    it 'displays the default error message' do
      render

      expect(rendered).to have_content('To resolve the problem, check the query syntax and try again.')
    end
  end

  context 'when search_results.error returns a custom error message' do
    let(:custom_error) { 'Custom error: Invalid query syntax' }

    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(true)
      allow(search_results).to receive(:error).with(scope).and_return(custom_error)
      allow(search_service).to receive_messages(search_type: 'basic', use_zoekt?: false)
    end

    it 'displays the custom error message' do
      render

      expect(rendered).to have_content(custom_error)
    end
  end

  context 'when search_type is zoekt and use_zoekt? is true' do
    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(false)
      allow(search_service).to receive_messages(search_type: 'zoekt', use_zoekt?: true)
    end

    it 'displays the Zoekt syntax help link' do
      render

      expect(rendered).to have_content('What is the supported syntax?')
      expect(rendered).to have_link('What is the supported syntax',
        href: '/help/user/search/exact_code_search.md#syntax')
      expect(rendered).to have_css('a[target="_blank"][rel="noopener noreferrer"]')
    end
  end

  context 'when search_type is basic' do
    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(false)
      allow(search_service).to receive_messages(search_type: 'basic', use_zoekt?: false)
    end

    it 'does not display the Zoekt syntax help link' do
      render

      expect(rendered).not_to have_content('What is the supported syntax?')
    end
  end

  context 'when search_type is advanced' do
    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(false)
      allow(search_service).to receive_messages(search_type: 'advanced', use_zoekt?: false)
    end

    it 'does not display the Zoekt syntax help link' do
      render

      expect(rendered).not_to have_content('What is the supported syntax?')
    end
  end

  context 'when search_type is zoekt but use_zoekt? is false' do
    before do
      allow(search_results).to receive(:respond_to?).with(:error).and_return(false)
      allow(search_service).to receive_messages(search_type: 'zoekt', use_zoekt?: false)
    end

    it 'does not display the Zoekt syntax help link' do
      render

      expect(rendered).not_to have_content('What is the supported syntax?')
    end
  end
end
