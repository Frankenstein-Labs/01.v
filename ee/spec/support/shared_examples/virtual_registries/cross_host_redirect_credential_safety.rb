# frozen_string_literal: true

RSpec.shared_examples 'a credential-safe cross-host redirect' do
  it 'follows the redirect without forwarding the upstream Authorization to the new host' do
    expect(execute).to be_success.and have_attributes(payload: a_hash_including(action: :download_file))

    expect(a_request(:head, redirect_url)
      .with { |req| !req.headers.transform_keys(&:downcase).key?('authorization') }).to have_been_made
    expect(a_request(:head, redirect_url)
      .with { |req| req.headers.transform_keys(&:downcase).key?('authorization') }).not_to have_been_made
  end
end
