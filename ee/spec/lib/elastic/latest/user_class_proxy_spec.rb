# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::UserClassProxy, :elasticsearch_settings_enabled, feature_category: :global_search do
  subject(:user_class_proxy) { described_class.new(User, use_separate_indices: true) }

  let(:query) { 'bob' }
  let(:options) { { search_level: 'global', current_user: user } }
  let_it_be(:user) { create(:user) }
  let(:elastic_search) { user_class_proxy.elastic_search(query, options: options) }
  let(:response) do
    Elasticsearch::Model::Response::Response.new(User,
      Elasticsearch::Model::Searching::SearchRequest.new(User, '*'))
  end

  describe '#elastic_search' do
    it 'delegates to UserQueryBuilder and calls search once', :aggregate_failures do
      allow(user_class_proxy).to receive(:search).and_return(response)
      expect(::Search::Elastic::UserQueryBuilder).to receive(:build).with(query: query, options: options)
      expect(user_class_proxy).to receive(:search).once

      elastic_search
    end
  end
end
