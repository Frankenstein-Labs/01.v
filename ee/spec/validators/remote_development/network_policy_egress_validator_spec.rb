# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::NetworkPolicyEgressValidator, feature_category: :workspaces do
  let(:model) do
    # noinspection RubyArgCount -- Rubymine is detecting wrong class here
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :egress
      alias_method :egress_before_type_cast, :egress

      validates :egress, 'remote_development/network_policy_egress': true
    end.new
  end

  using RSpec::Parameterized::TableSyntax

  where(:egress, :validity, :errors) do
    # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
    nil                                                 | false | { egress: ['must be an array'] }
    'not-an-array'                                      | false | { egress: ['must be an array'] }
    [nil]                                               | false | { egress: ['must be an array of hash'] }
    [{ allow: nil }]                                    | false | { egress: ["must be an array of hash containing 'allow' attribute of type string"] }
    [{ except: [] }]                                    | false | { egress: ["must be an array of hash containing 'allow' attribute of type string"] }
    [{ allow: 1 }]                                      | false | { egress: ["'allow: 1' must be a string"] }
    [{ allow: '10.0.0.0/32', except: nil }]             | false | { egress: ["'except: ' must be an array of string"] }
    [{ allow: '10.0.0.0/40', except: [] }]              | false | { egress: ["IP '10.0.0.0/40' is not a valid CIDR: Prefix must be in range 0..32, got: 40"] }
    [{ allow: '10.0.0.0/32', except: ['10.0.0.0/40'] }] | false | { egress: ["IP '10.0.0.0/40' is not a valid CIDR: Prefix must be in range 0..32, got: 40"] }
    []                                                  | true  | {}
    [{ allow: '10.0.0.0/32', except: [] }]              | true  | {}
    # rubocop:enable Layout/LineLength
  end

  with_them do
    before do
      model.egress = egress
      model.validate
    end

    it { expect(model.valid?).to eq(validity) }
    it { expect(model.errors.messages).to eq(errors) }
  end
end
