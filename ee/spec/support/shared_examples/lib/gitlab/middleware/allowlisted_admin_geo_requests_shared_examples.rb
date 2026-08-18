# frozen_string_literal: true

RSpec.shared_examples 'allowlisted /admin/geo requests' do
  include DisallowRequestMatchers

  shared_examples 'allowlisted request' do |request_type, request_url|
    it "expects a #{request_type.upcase} request to #{request_url} to be allowed" do
      response = request.send(request_type, request_url)

      expect(response).not_to be_redirect
      expect(subject).not_to disallow_request
    end
  end

  context 'allowlisted requests' do
    it_behaves_like 'allowlisted request', :patch, '/admin/geo/sites/1'
  end
end
