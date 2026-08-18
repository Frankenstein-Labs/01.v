# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::DefaultRuntimeClassValidator, feature_category: :workspaces do
  let(:model) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :default_runtime_class
      alias_method :default_runtime_class_before_type_cast, :default_runtime_class

      validates :default_runtime_class, "remote_development/default_runtime_class": true
    end.new
  end

  using RSpec::Parameterized::TableSyntax

  where(:default_runtime_class, :validity, :errors) do
    # rubocop:disable Layout/LineLength -- The RSpec table syntax often requires long lines for errors
    nil          | false | { default_runtime_class: ["must be a string"] }
    1            | false | { default_runtime_class: ["must be a string"] }
    ("a" * 254)  | false | { default_runtime_class: ["must be 253 characters or less"] }
    "-a"         | false | { default_runtime_class: ["must start and end with an alphanumeric character"] }
    "a-"         | false | { default_runtime_class: ["must start and end with an alphanumeric character"] }
    "a-.=a"      | false | { default_runtime_class: ["must contain only lowercase alphanumeric characters, '-', and '.'"] }
    ""           | true  | {}
    "example"    | true  | {}
    "1example"   | true  | {}
    "example1"   | true  | {}
    "1"          | true  | {}
    "a-.1"       | true  | {}
    # rubocop:enable Layout/LineLength
  end

  with_them do
    before do
      model.default_runtime_class = default_runtime_class
      model.validate
    end

    it { expect(model.valid?).to eq(validity) }
    it { expect(model.errors.messages).to eq(errors) }
  end
end
