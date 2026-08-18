# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_keys, class: 'CloudConnector::Keys' do
    secret_key do
      OpenSSL::PKey::RSA.new(2048).to_pem
    end
  end
end
