# frozen_string_literal: true

RSpec.shared_examples 'an API request requiring an exclusive project secret operation lease' do
  include ExclusiveLeaseHelpers

  it 'tries to obtain an exclusive lease for project secret operation' do
    lease_key = "project_secret_operation:project_#{project.id}"

    expect_to_obtain_exclusive_lease(lease_key, 'uuid', timeout: 30.seconds.to_i)

    post_mutation
  end

  it 'returns an error if cannot achieve an exclusive lease for project secret operation' do
    lease_key = "project_secret_operation:project_#{project.id}"
    stub_exclusive_lease_taken(lease_key)

    post_mutation

    expect(mutation_response['errors']).to include('Another secret operation in progress')
  end
end

RSpec.shared_examples 'an API request requiring an exclusive group secret operation lease' do
  include ExclusiveLeaseHelpers

  it 'tries to obtain an exclusive lease for group secret operation' do
    lease_key = "group_secret_operation:group_#{group.id}"

    expect_to_obtain_exclusive_lease(lease_key, 'uuid', timeout: 30.seconds.to_i)

    post_mutation
  end

  it 'returns an error if cannot achieve an exclusive lease for group secret operation' do
    lease_key = "group_secret_operation:group_#{group.id}"
    stub_exclusive_lease_taken(lease_key)

    post_mutation

    expect(mutation_response['errors']).to include('Another secret operation in progress')
  end
end
