# frozen_string_literal: true

SecretsManagement::SecretsManagerClient.configure do |c|
  c.host = if Rails.env.test?
             "http://127.0.0.1:9800"
           else
             SecretsManagement::ProjectSecretsManager.internal_server_url
           end

  c.base_path = 'v1'
end
