# frozen_string_literal: true

RSpec.shared_context 'with correct create params' do
  let(:maintainer_access_level) { [{ access_level: Gitlab::Access::MAINTAINER }] }
  let(:access_level_params) do
    {
      merge_access_levels_attributes: maintainer_access_level,
      push_access_levels_attributes: maintainer_access_level
    }
  end

  let(:create_params) { attributes_for(:protected_branch).merge(access_level_params) }
end

RSpec.shared_context 'with correct update params' do
  let(:update_params) { { id: protected_branch, name: 'new name' } }
end
