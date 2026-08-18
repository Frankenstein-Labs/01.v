# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::ImagePullSecretsValidator, feature_category: :workspaces do
  let(:model) do
    # noinspection RubyArgCount -- Rubymine is detecting wrong class here
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :image_pull_secrets
      alias_method :image_pull_secrets_before_type_cast, :image_pull_secrets

      validates :image_pull_secrets, 'remote_development/image_pull_secrets': true
    end.new
  end

  let(:image_pull_secrets) do
    [{ name: 'secret-a', namespace: 'namespace-a' }, { name: 'secret-b', namespace: 'namespace-b' }]
  end

  before do
    model.image_pull_secrets = image_pull_secrets
    model.validate
  end

  context 'when image_pull_secrets have unique names' do
    it 'is valid' do
      expect(model.valid?).to be(true)
      expect(model.errors.messages).to eq({})
    end
  end

  context 'when image_pull_secrets contain duplicate names' do
    let(:image_pull_secrets) do
      [
        { name: 'secret-b', namespace: 'namespace-a' },
        { name: 'secret-b', namespace: 'namespace-b' },
        { name: 'secret-c', namespace: 'namespace-a' },
        { name: 'secret-c', namespace: 'namespace-b' }
      ]
    end

    it 'is invalid' do
      expect(model.valid?).to be(false)
      expect(model.errors.messages[:image_pull_secrets]).to match_array(
        ["name: secret-c exists in more than one image pull secret, image pull secrets must have a unique 'name'",
          "name: secret-b exists in more than one image pull secret, image pull secrets must have a unique 'name'"]
      )
    end
  end
end
