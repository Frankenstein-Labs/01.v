# frozen_string_literal: true

module Security
  module PolicyCspHelpers
    def stub_csp_group(group)
      allow(Security::PolicySetting)
        .to receive(:in_organization).with(an_instance_of(Organizations::Organization))
                                      .and_return(
                                        Security::PolicySetting.new(csp_namespace_id: group&.id)
                                      )
    end
  end
end
