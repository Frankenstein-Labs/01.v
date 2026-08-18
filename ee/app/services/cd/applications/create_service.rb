# frozen_string_literal: true

module Cd
  module Applications
    class CreateService
      def initialize(parent:, current_user: nil, params: {})
        @parent = parent
        @current_user = current_user
        @params = params.dup
        @services = Array(@params.delete(:services))
      end

      def execute
        application = ::Cd::Application.new(params.merge(organization: parent))

        ::Cd::Application.transaction do
          application.save!

          services.each do |service_params|
            artifact_sources = Array(service_params.delete(:artifact_sources))
            service = application.services.create!(service_params.merge(organization: parent))

            artifact_sources.each do |artifact_source_params|
              service.artifact_sources.create!(artifact_source_params.merge(organization: parent))
            end
          end
        end

        ServiceResponse.success(payload: { application: application })
      rescue ActiveRecord::RecordInvalid => e
        ServiceResponse.error(
          message: e.record.errors.full_messages,
          payload: { application: application }
        )
      end

      private

      attr_reader :parent, :current_user, :params, :services
    end
  end
end
