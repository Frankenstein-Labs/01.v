# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Repository::BlobType, feature_category: :source_code_management do
  specify { expect(described_class.graphql_name).to eq('RepositoryBlob') }
  specify { expect(described_class).to have_graphql_field(:code_owners, calls_gitaly?: true) }
  specify { expect(described_class).to have_graphql_field(:show_duo_workflow_action) }
end
