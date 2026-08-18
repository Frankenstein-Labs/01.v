# frozen_string_literal: true

module AuditEvents
  # AwsExternallyDestinationable::AWS_REGION_REGEXP is the single source of truth for
  # the region format. It is applied to the legacy AmazonS3Configuration models by
  # that concern, and to the current destination models by AwsDestinationValidator.
  # These cases exercise both paths.
  #
  # Both strip surrounding whitespace before validating, so a padded region is
  # expected to be valid. Embedded newlines are not stripped and the regexp anchors
  # to the whole string, so they are rejected.
  module AwsRegionTestCases
    CASES = [
      ['us-east-1', true],
      ['us-gov-east-1', true],
      ['ap-southeast-4', true],
      ['cn-north-1', true],
      ['aws-us-gov-global', true],
      ['  us-east-1  ', true],            # stripped before validation
      ['us east 1', false],
      ['US_EAST_1', false],
      ['US-EAST-1', false],               # SigV4 signs with the literal region
      ['us-east-1.amazonaws.com', false],
      ['-us-east-1', false],
      ['us-east-1-', false],
      ["us–east–1", false], # en dash instead of hyphen
      ["us\neast-1", false], # anchors must be \A/\z, not ^/$
      ["us-east-1\nevil", false]
    ].freeze
  end
end
