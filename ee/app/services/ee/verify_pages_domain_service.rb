# frozen_string_literal: true

module EE
  module VerifyPagesDomainService
    extend ::Gitlab::Utils::Override

    override :after_successful_verification
    def after_successful_verification
      super

      ::Groups::EnterpriseUsers::BulkAssociateByDomainWorker.perform_async(domain.id)
    end
  end
end
