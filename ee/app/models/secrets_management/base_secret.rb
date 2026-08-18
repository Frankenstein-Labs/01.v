# frozen_string_literal: true

module SecretsManagement
  class BaseSecret
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveModel::Dirty
    include SecretStatus

    attribute :name, :string
    attribute :description, :string
    attribute :environment, :string
    attribute :rotation_info
    attribute :metadata_version, :integer, default: 0
    attribute :create_started_at
    attribute :create_completed_at
    attribute :update_started_at
    attribute :update_completed_at

    define_attribute_methods :environment

    SECRET_NAME_FORMAT = /\A[a-zA-Z0-9_]+\z/
    SECRET_NAME_FORMAT_MESSAGE = "can contain only letters, digits and '_'."

    validates :name,
      presence: true,
      length: { maximum: 255 },
      format: { with: SECRET_NAME_FORMAT, message: SECRET_NAME_FORMAT_MESSAGE }

    validates :environment, presence: true

    def initialize(attributes = {})
      super

      # Mark current state as the baseline for dirty tracking
      changes_applied
    end

    def ==(other)
      other.is_a?(self.class) && attributes == other.attributes
    end

    # Add methods to track attribute changes
    def environment=(val)
      environment_will_change! unless val == environment
      super
    end
  end
end
