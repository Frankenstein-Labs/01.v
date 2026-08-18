# frozen_string_literal: true

RSpec.shared_context 'with pipeline execution policy specific fields' do
  let(:type_specific_fields) do
    %i[source policy_blob_file_path warnings]
  end
end

RSpec.shared_context 'with approval policy specific fields' do
  let(:type_specific_fields) do
    %i[source action_approvers user_approvers all_group_approvers role_approvers custom_roles deprecatedProperties
      enforcement_type]
  end
end

RSpec.shared_context 'with scan execution policy specific fields' do
  let(:type_specific_fields) do
    %i[source deprecatedProperties]
  end
end

RSpec.shared_context 'with vulnerability management policy specific fields' do
  let(:type_specific_fields) do
    %i[source]
  end
end

RSpec.shared_context 'with dependency firewall policy specific fields' do
  let(:type_specific_fields) do
    %i[source]
  end
end
