# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:context, :duo_workflow_service) do
    ::Tasks::Gitlab::AiGateway::Utils.ensure_duo_workflow_service
  end

  config.after(:suite) do
    ::Tasks::Gitlab::AiGateway::Utils.terminate_duo_workflow_service
  end
end
