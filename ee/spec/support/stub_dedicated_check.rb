# frozen_string_literal: true

RSpec.configure do
  RSpec.shared_context 'with dedicated instances' do
    before do
      stub_application_setting(gitlab_dedicated_instance: true)
    end
  end

  RSpec.configure do |rspec|
    rspec.include_context 'with dedicated instances', dedicated: true
  end
end
