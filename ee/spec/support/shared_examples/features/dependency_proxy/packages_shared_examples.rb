# frozen_string_literal: true

RSpec.shared_examples 'returning forbidden error when local requests are not allowed' do |package_type|
  before do
    allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
    stub_application_setting(allow_local_requests_from_web_hooks_and_services: false)
  end

  it 'returns forbidden error' do
    expect { response }
      .to not_change { project.packages.public_send(package_type).count }
      .and not_change { ::Packages::PackageFile.count }
    expect(response.code).to eq(403)
  end
end
