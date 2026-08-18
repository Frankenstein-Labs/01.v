# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::LabelsValidator, feature_category: :workspaces do
  let(:model) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :labels
      alias_method :labels_before_type_cast, :labels

      validates :labels, "remote_development/labels": true
    end.new
  end

  using RSpec::Parameterized::TableSyntax

  where(:labels, :validity, :errors) do
    # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
    nil                                                    | false | { labels: ["must be an hash"] }
    "not-an-hash"                                          | false | { labels: ["must be an hash"] }
    { 1 => "example" }                                     | false | { labels: ["key: 1 must be a string"] }
    { "example" => 1 }                                     | false | { labels: ["value: 1 must be a string"] }
    { "gitlab.com/test" => "example" }                     | false | { labels: ["key: gitlab.com/test is reserved for internal usage"] }
    { "test.kubernetes.io/test" => "example" }             | false | { labels: ["key: test.kubernetes.io/test is reserved for internal usage"] }
    { "config.k8s.io/owning-inventory" => "example" }      | false | { labels: ["key: config.k8s.io/owning-inventory is reserved for internal usage"] }
    { "reserved.gitlab.com/test" => "example" }            | false | { labels: ["key: reserved.gitlab.com/test is reserved for internal usage"] }
    { "valid.dns.name/-invalid-name" => "example" }        | false | { labels: ["key: valid.dns.name/-invalid-name must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "valid.dns.name/" => "example" }                     | false | { labels: ["key: valid.dns.name/ must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "/almost-valid-name" => "example" }                  | false | { labels: ["key: /almost-valid-name must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "" => "example" }                                    | false | { labels: ["key:  must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { ("a" * 64) => "example" }                            | false | { labels: ["key: #{'a' * 64} must have name component with 63 characters or less, and start/end with an alphanumeric character"] }
    { "#{'a' * 264}/valid-name" => "example" }             | false | { labels: ["key: #{'a' * 264}/valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { "-.invalid.dns/valid-name" => "example" }            | false | { labels: ["key: -.invalid.dns/valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { ".invalid.dns/valid-name" => "example" }             | false | { labels: ["key: .invalid.dns/valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { "invalid.dns./valid-name" => "example" }             | false | { labels: ["key: invalid.dns./valid-name must have prefix component with 253 characters or less, and have a valid DNS subdomain as a prefix"] }
    { "example" => ("a" * 64) }                            | false | { labels: ["value: #{'a' * 64} must be 63 characters or less, and start/end with an alphanumeric character"] }
    {}                                                     | true  | {}
    { "example" => "" }                                    | true  | {}
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
      model.labels = labels
      model.validate
    end

    it { expect(model.valid?).to eq(validity) }
    it { expect(model.errors.messages).to eq(errors) }
  end
end
