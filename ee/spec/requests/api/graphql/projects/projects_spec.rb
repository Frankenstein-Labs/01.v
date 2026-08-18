# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a collection of projects', feature_category: :groups_and_projects do
  it_behaves_like 'getting a collection of projects EE' do
    it_behaves_like 'projects graphql query with SAML session filtering'
  end
end
