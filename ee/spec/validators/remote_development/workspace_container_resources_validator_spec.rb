# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::WorkspaceContainerResourcesValidator, feature_category: :workspaces do
  let(:model) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :resources
      alias_method :resources_before_type_cast, :resources

      validates :resources, 'remote_development/workspace_container_resources': true
    end.new
  end

  using RSpec::Parameterized::TableSyntax

  where(:resources, :validity, :errors) do
    # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
    nil                                                                | false | { resources: ['must be a hash'] }
    'not-an-array'                                                     | false | { resources: ['must be a hash'] }
    { limits: nil }                                                    | false | { resources: ["must be a hash containing 'limits' attribute of type hash"] }
    { limits: { cpu: "500Invalid", memory: "1Gi" }, requests: nil }    | false | { resources: ["must be a hash containing 'requests' attribute of type hash"] }
    { limits: 1 }                                                      | false | { resources: ["must be a hash containing 'limits' attribute of type hash"] }
    { limits: { cpu: "500Invalid", memory: "1Gi" }, requests: 1 }      | false | { resources: ["must be a hash containing 'requests' attribute of type hash"] }
    { limits: {}, requests: {} }                                       | false | { resources_limits: ["must be a hash containing 'cpu' and 'memory' attribute of type string"], resources_requests: ["must be a hash containing 'cpu' and 'memory' attribute of type string"] }
    { limits: { cpu: 1, memory: 5 }, requests: { cpu: 1, memory: 5 } } | false | { resources_limits: ["'cpu: 1' must be a string", "'memory: 5' must be a string"], resources_requests: ["'cpu: 1' must be a string", "'memory: 5' must be a string"] }
    {}                                                                 | true  | {}
    { limits: { cpu: "500m", memory: "1Gi" }, requests: { cpu: "200m", memory: "0.5Gi" } } | true | {}
    # rubocop:enable Layout/LineLength
  end

  with_them do
    before do
      model.resources = resources
      model.validate
    end

    it { expect(model.valid?).to eq(validity) }
    it { expect(model.errors.messages).to eq(errors) }
  end
end
