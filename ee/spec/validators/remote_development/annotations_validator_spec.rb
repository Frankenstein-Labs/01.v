# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::AnnotationsValidator, feature_category: :workspaces do
  let(:model) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :annotations
      alias_method :annotations_before_type_cast, :annotations

      validates :annotations, "remote_development/annotations": true
    end.new
  end

  using RSpec::Parameterized::TableSyntax

  where(:annotations, :validity, :errors) do
    # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
    nil                                                    | false | { annotations: ["must be an hash"] }
    "not-an-hash"                                          | false | { annotations: ["must be an hash"] }
    { 1 => "example" }                                     | false | { annotations: ["key: 1 must be a string"] }
    { "example" => 1 }                                     | false | { annotations: ["value: 1 must be a string"] }
    { "gitlab.com/test" => "example" }                     | false | { annotations: ["key: gitlab.com/test is reserved for internal usage"] }
    { "test.kubernetes.io/test" => "example" }             | false | { annotations: ["key: test.kubernetes.io/test is reserved for internal usage"] }
    { "config.k8s.io/owning-inventory" => "example" }      | false | { annotations: ["key: config.k8s.io/owning-inventory is reserved for internal usage"] }
    { "reserved.gitlab.com/test" => "example" }            | false | { annotations: ["key: reserved.gitlab.com/test is reserved for internal usage"] }
    { "valid.dns.name/-invalid-name" => "example" }        | false | { annotations: ["key: valid.dns.name/-invalid-name must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "valid.dns.name/" => "example" }                     | false | { annotations: ["key: valid.dns.name/ must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "/almost-valid-name" => "example" }                  | false | { annotations: ["key: /almost-valid-name must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "" => "example" }                                    | false | { annotations: ["key:  must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { ("a" * 64) => "example" }                            | false | { annotations: ["key: #{'a' * 64} must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "#{'a' * 264}/valid-name" => "example" }             | false | { annotations: ["key: #{'a' * 264}/valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { "-.invalid.dns/valid-name" => "example" }            | false | { annotations: ["key: -.invalid.dns/valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { ".invalid.dns/valid-name" => "example" }             | false | { annotations: ["key: .invalid.dns/valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { "invalid.dns./valid-name" => "example" }             | false | { annotations: ["key: invalid.dns./valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    {}                                                     | true  | {}
    { "example" => "valid" }                               | true  | {}
    { "1example" => "valid" }                              | true  | {}
    { "example1" => "valid" }                              | true  | {}
    { "test.prefix/example" => "valid" }                   | true  | {}
    { "1test.prefix/example" => "valid" }                  | true  | {}
    { "test.prefix1/example" => "valid" }                  | true  | {}
    # rubocop:enable Layout/LineLength
  end

  with_them do
    before do
      model.annotations = annotations
      model.validate
    end

    it { expect(model.valid?).to eq(validity) }
    it { expect(model.errors.messages).to eq(errors) }
  end
end
