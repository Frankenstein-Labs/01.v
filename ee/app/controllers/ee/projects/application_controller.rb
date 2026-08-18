# frozen_string_literal: true

module EE
  module Projects
    module ApplicationController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      private

      override :auth_proc
      def auth_proc
        if params[:controller] == "projects" && params[:action] == "restore"
          super
        else
          ->(project) { !project.self_deletion_in_progress_or_hidden? }
        end
      end
    end
  end
end
