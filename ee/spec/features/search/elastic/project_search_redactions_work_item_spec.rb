# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project elastic search redactions work_item', feature_category: :global_search do
  it_behaves_like 'a redacted search results page' do
    let(:search_path) { project_path(public_restricted_project) }
  end
end
