# frozen_string_literal: true

RSpec.shared_examples 'an operation requiring an exclusive project secret operation lease' do |timeout = 30.seconds|
  include ExclusiveLeaseHelpers

  it 'tries to obtain an exclusive lease for project secret operation' do
    lease_key = "project_secret_operation:project_#{project.id}"

    expect_to_obtain_exclusive_lease(lease_key, 'uuid', timeout: timeout.to_i)

    result
  end

  it 'returns an error if cannot achieve an exclusive lease for project secret operation' do
    lease_key = "project_secret_operation:project_#{project.id}"
    stub_exclusive_lease_taken(lease_key)

    result

    expect(result.message).to include('Another secret operation in progress')
    expect(result).not_to be_success
  end
end

RSpec.shared_examples 'an operation requiring an exclusive group secret operation lease' do |timeout = 30.seconds|
  include ExclusiveLeaseHelpers

  it 'tries to obtain an exclusive lease for group secret operation' do
    lease_key = "group_secret_operation:group_#{group.id}"

    expect_to_obtain_exclusive_lease(lease_key, 'uuid', timeout: timeout.to_i)

    result
  end

  it 'returns an error if cannot achieve an exclusive lease for group secret operation' do
    lease_key = "group_secret_operation:group_#{group.id}"
    stub_exclusive_lease_taken(lease_key)

    result

    expect(result.message).to include('Another secret operation in progress')
    expect(result).not_to be_success
  end
end
