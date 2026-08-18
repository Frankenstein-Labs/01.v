# frozen_string_literal: true

module Security
  module TokenStatus
    UNKNOWN = 0
    ACTIVE = 1
    INACTIVE = 2

    STATUSES = {
      unknown: UNKNOWN,
      active: ACTIVE,
      inactive: INACTIVE
    }.freeze
  end
end
