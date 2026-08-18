# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::SharedNamespaceValidator, feature_category: :workspaces do
  let(:model) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :shared_namespace
      alias_method :shared_namespace_before_type_cast, :shared_namespace

      validates :shared_namespace, "remote_development/shared_namespace": true
    end.new
  end

  using RSpec::Parameterized::TableSyntax

  where(:shared_namespace, :validity, :errors) do # -- The RSpec table syntax often requires long lines for errors
    nil | false | { shared_namespace: ["must be a string"] }
    1 | false | { shared_namespace: ["must be a string"] }
    ("a" * 64) | false | { shared_namespace: ["must be 63 characters or less"] }
    "-a"         | false | { shared_namespace: ["must start and end with an alphanumeric character"] }
    "a-"         | false | { shared_namespace: ["must start and end with an alphanumeric character"] }
    "a-.=a"      | false | { shared_namespace: ["must contain only lowercase alphanumeric characters or '-'"] }
    "a-.1"       | false | { shared_namespace: ["must contain only lowercase alphanumeric characters or '-'"] }
    ""           | true  | {}
    "example"    | true  | {}
    "1example"   | true  | {}
    "example1"   | true  | {}
    "1"          | true  | {}
  end

  with_them do
    before do
      model.shared_namespace = shared_namespace
      model.validate
    end

    it { expect(model.valid?).to eq(validity) }
    it { expect(model.errors.messages).to eq(errors) }
  end
end
