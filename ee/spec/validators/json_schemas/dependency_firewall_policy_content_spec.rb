# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'dependency_firewall_policy_content.json', feature_category: :dependency_firewall do
  let(:schema_path) do
    Rails.root.join("ee/app/validators/json_schemas/dependency_firewall_policy_content.json")
  end

  let(:schema) { JSONSchemer.schema(schema_path) }
  let(:validation_result) { schema.validate(policy, output_format: 'basic') }

  let(:policy) do
    {
      name: 'License Policy #1',
      description: 'Two rules for licenses',
      enabled: true,
      enforcement_type: 'warn',
      bypass_settings: { users: [{ id: 123 }], access_tokens: [{ id: 334 }] },
      rules: [
        {
          type: 'license',
          denied: [{ name: 'NIST Software License' }, { name: 'NTP License' }],
          exceptions: [{ purl: 'pkg:npm/my-internal-lib' }]
        },
        {
          type: 'license',
          allowed: [{ name: 'MIT License' }, { name: 'Apache License 2.0' }],
          exceptions: [{ purl: 'pkg:npm/my-internal-lib' }]
        }
      ]
    }
  end

  def expect_errors_to_include(expected_error)
    expect(validation_result["errors"].pluck("error")).to include expected_error
  end

  context 'when policy has empty rules array' do
    before do
      policy[:rules] = []
    end

    specify do
      expect(validation_result["valid"]).to be false
      expect_errors_to_include('array size at `/rules` is less than: 1')
    end
  end

  context 'when policy has rules' do
    specify { expect(validation_result["valid"]).to be true }

    context 'with both allowed and denied is invalid' do
      before do
        policy[:rules] = [{
          type: 'license',
          denied: [{ name: 'NIST Software License' }, { name: 'NTP License' }],
          allowed: [{ name: 'MIT License' }, { name: 'Apache License 2.0' }]
        }]
      end

      specify do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0` does not match exactly one `oneOf` schema')
      end
    end

    context 'when exception purl is invalid' do
      before do
        policy[:rules][0][:exceptions][0][:purl] = 'notpkg:npm/my-internal-lib'
      end

      specify do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('string at `/rules/0/exceptions/0/purl` does not match pattern: ^pkg:')
      end
    end
  end

  context 'when policy has invalid structure' do
    before do
      policy[:rules] = 'not_an_array'
    end

    specify do
      expect(validation_result["valid"]).to be false
      expect_errors_to_include('value at `/rules` is not an array')
    end
  end

  context 'when policy has additional properties' do
    before do
      policy[:unexpected_field] = 'value'
    end

    specify do
      expect(validation_result["valid"]).to be false
      expect_errors_to_include('object property at `/unexpected_field` is a disallowed additional property')
    end
  end

  context 'when policy has vulnerability rules' do
    before do
      policy[:rules] = [{ type: 'vulnerability', denied: [{ severity: 'critical' }] }]
    end

    specify { expect(validation_result["valid"]).to be true }

    context 'with allowed instead of denied' do
      before do
        policy[:rules] = [{ type: 'vulnerability', allowed: [{ severity: 'high' }] }]
      end

      specify { expect(validation_result["valid"]).to be true }
    end

    context 'with both denied and allowed' do
      before do
        policy[:rules] = [{
          type: 'vulnerability',
          denied: [{ severity: 'critical' }],
          allowed: [{ severity: 'high' }]
        }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0` does not match exactly one `oneOf` schema')
      end
    end
  end

  context 'when policy has malicious rules' do
    before do
      policy[:rules] = [
        {
          type: 'malicious',
          denied: [{ is_malicious: true }],
          exceptions: [{ purl: 'pkg:npm/my-internal-lib' }]
        }
      ]
    end

    specify { expect(validation_result["valid"]).to be true }

    context 'with allowed instead of denied' do
      before do
        policy[:rules] = [{ type: 'malicious', allowed: [{ is_malicious: true }] }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0` does not match conditional `then` schema')
      end
    end

    context 'with both denied and allowed' do
      before do
        policy[:rules] = [{
          type: 'malicious',
          denied: [{ is_malicious: true }],
          allowed: [{ is_malicious: true }]
        }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0` does not match exactly one `oneOf` schema')
      end
    end

    context 'with neither denied nor allowed' do
      before do
        policy[:rules] = [{ type: 'malicious' }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0` does not match exactly one `oneOf` schema')
      end
    end

    context 'with is_malicious: false (not a valid value)' do
      before do
        policy[:rules][0][:denied] = [{ is_malicious: false }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0/denied/0/is_malicious` is not one of: [true]')
      end
    end

    context 'with exception missing both purl and id' do
      before do
        policy[:rules][0][:exceptions] = [{}]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('value at `/rules/0/exceptions/0` does not match any `anyOf` schemas')
      end
    end

    context 'with exception containing unknown property' do
      before do
        policy[:rules][0][:exceptions] = [{ purl: 'pkg:npm/x', foo: 'extra' }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('object property at `/rules/0/exceptions/0/foo` is a disallowed additional property')
      end
    end

    context 'with a license name item in denied (cross-type)' do
      before do
        policy[:rules][0][:denied] = [{ name: 'MIT' }]
      end

      specify :aggregate_failures do
        expect(validation_result["valid"]).to be false
        expect_errors_to_include('object at `/rules/0/denied/0` is missing required properties: is_malicious')
      end
    end
  end
end
