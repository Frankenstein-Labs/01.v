# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Tokens::TokenIssuer, feature_category: :plan_provisioning do
  let(:name_or_url) { 'https://example.com' }
  let(:jwt_subject) { 'test-subject' }
  let(:realm) { 'test-realm' }
  let(:ttl) { 3600 }
  let(:key) { build(:cloud_connector_keys) }
  let(:extra_claims) { { 'custom_claim' => 'value' } }

  let(:add_on_1) { build(:cloud_connector_add_on, name: 'addon-1') }
  let(:add_on_2) { build(:cloud_connector_add_on, name: 'addon-2') }
  let(:backend) { build(:cloud_connector_backend_service) }

  let(:unit_primitive_no_cutoff_date) do
    build(:cloud_connector_unit_primitive, :no_cut_off_date,
      name: 'unit_primitive_no_cutoff_date',
      add_ons: [add_on_1],
      backend_services: [backend]
    )
  end

  let(:unit_primitive_free_access) do
    build(:cloud_connector_unit_primitive, :future_cut_off_date,
      name: 'unit_primitive_free_access',
      add_ons: [add_on_1],
      backend_services: [backend]
    )
  end

  let(:unit_primitive_paid_add_on_1) do
    build(:cloud_connector_unit_primitive,
      name: 'unit_primitive_paid_add_on_1',
      add_ons: [add_on_1],
      backend_services: [backend]
    )
  end

  let(:unit_primitive_paid_add_on_1_and_2) do
    build(:cloud_connector_unit_primitive,
      name: 'unit_primitive_paid_add_on_1_and_2',
      add_ons: [add_on_1, add_on_2],
      backend_services: [backend]
    )
  end

  subject(:token_issuer) do
    described_class.new(
      name_or_url: name_or_url,
      subject: jwt_subject,
      realm: realm,
      active_add_ons: active_add_ons,
      ttl: ttl,
      jwk: key.to_jwk,
      extra_claims: extra_claims
    )
  end

  describe '#token' do
    let(:expected_claims) do
      {
        'iss' => name_or_url,
        'exp' => an_instance_of(Integer),
        'iat' => an_instance_of(Integer),
        'nbf' => an_instance_of(Integer),
        'jti' => an_instance_of(String),
        'aud' => [backend.jwt_aud],
        'sub' => jwt_subject,
        'gitlab_realm' => realm,
        'scopes' => [],
        'custom_claim' => 'value'
      }
    end

    before do
      allow(Gitlab::CloudConnector::DataModel::UnitPrimitive).to receive(:all)
        .and_return([
          unit_primitive_no_cutoff_date,
          unit_primitive_free_access,
          unit_primitive_paid_add_on_1,
          unit_primitive_paid_add_on_1_and_2
        ])
    end

    subject(:decoded_token) { key.decode_token(token_issuer.token).first }

    context 'when there are no active add-ons' do
      let(:active_add_ons) { [] }

      it 'generates a token with UPs in free access' do
        expect(decoded_token).to match(expected_claims.merge(
          'scopes' => %w[unit_primitive_no_cutoff_date unit_primitive_free_access]
        ))
      end
    end

    context 'when customer owns only add-on 1' do
      let(:active_add_ons) { [add_on_1.name] }

      it 'generates a token with all UPs' do
        expect(decoded_token).to match(expected_claims.merge(
          'scopes' => %w[
            unit_primitive_no_cutoff_date
            unit_primitive_free_access
            unit_primitive_paid_add_on_1
            unit_primitive_paid_add_on_1_and_2
          ]
        ))
      end
    end

    context 'when customer owns only add-on 2' do
      let(:active_add_ons) { [add_on_2.name] }

      it 'generates a token with UPs in free access and add-on 2' do
        expect(decoded_token).to match(expected_claims.merge(
          'scopes' => %w[
            unit_primitive_no_cutoff_date
            unit_primitive_free_access
            unit_primitive_paid_add_on_1_and_2
          ]
        ))
      end
    end

    context 'when customer owns both add-ons' do
      let(:active_add_ons) { [add_on_1.name, add_on_2.name] }

      it 'generates a token with all UPs' do
        expect(decoded_token).to match(expected_claims.merge(
          'scopes' => %w[
            unit_primitive_no_cutoff_date
            unit_primitive_free_access
            unit_primitive_paid_add_on_1
            unit_primitive_paid_add_on_1_and_2
          ]
        ))
      end
    end
  end
end
