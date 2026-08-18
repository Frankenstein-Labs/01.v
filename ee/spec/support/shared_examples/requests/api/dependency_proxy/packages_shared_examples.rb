# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'returning a workhorse sendurl response with' do |headers: {}|
  let(:expected_restrict_forwarded_response_headers) do
    {
      'Enabled' => true,
      'AllowList' => ::API::Concerns::DependencyProxy::PackagesHelpers::ALLOWED_HEADERS
    }
  end

  it 'returns a workhorse sendurl response' do
    subject

    expect(response).to have_gitlab_http_status(:ok)
    expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('send-url:')
    expect(response.headers['Content-Type']).to eq('application/octet-stream')
    expect(response.headers['Content-Length'].to_i).to eq(0)
    expect(response.body).to eq('')

    send_data_type, send_data = workhorse_send_data

    expect(send_data_type).to eq('send-url')
    expect(send_data['URL']).to be_present
    expect(send_data['AllowRedirects']).to be_truthy
    expect(send_data['DialTimeout']).to eq('10s')
    expect(send_data['ResponseHeaderTimeout']).to eq('10s')
    expect(send_data['ErrorResponseStatus']).to eq(502)
    expect(send_data['TimeoutResponseStatus']).to eq(504)
    expect(send_data['Header']).to eq(headers)
    expect(send_data['RestrictForwardedResponseHeaders']).to eq(expected_restrict_forwarded_response_headers)
  end
end

RSpec.shared_examples 'returning a workhorse senddependency response with' do
  |headers: nil, upload_url_present: true, upload_method: 'POST'|
  let(:expected_restrict_forwarded_response_headers) do
    {
      'Enabled' => true,
      'AllowList' => ::API::Concerns::DependencyProxy::PackagesHelpers::ALLOWED_HEADERS
    }
  end

  it 'returns a workhorse senddependency response' do
    subject

    expect(response).to have_gitlab_http_status(:ok)
    expect(response.headers[Gitlab::Workhorse::SEND_DATA_HEADER]).to start_with('send-dependency:')
    expect(response.headers['Content-Type']).to eq('application/octet-stream')
    expect(response.headers['Content-Length'].to_i).to eq(0)
    expect(response.body).to eq('')

    send_data_type, send_data = workhorse_send_data

    expect(send_data_type).to eq('send-dependency')
    expect(send_data['Url']).to be_present
    expect(send_data['Headers']).to eq(headers)
    expect(send_data['RestrictForwardedResponseHeaders']).to eq(expected_restrict_forwarded_response_headers)

    upload_config = send_data['UploadConfig']

    expect(upload_config['Method']).to eq(upload_method)

    if upload_url_present
      expect(upload_config['Url']).to be_present
    else
      expect(upload_config['Url']).not_to be_present
    end
  end
end
