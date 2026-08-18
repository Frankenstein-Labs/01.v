# frozen_string_literal: true

module EE
  module API
    module Helpers
      module RemoteMirrorsHelpers
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          params :mirror_branches_setting_ee do
            optional :mirror_branch_regex, type: String, desc: 'Determines if only matched branches are mirrored'
            mutually_exclusive :only_protected_branches, :mirror_branch_regex
          end
        end
      end
    end
  end
end
