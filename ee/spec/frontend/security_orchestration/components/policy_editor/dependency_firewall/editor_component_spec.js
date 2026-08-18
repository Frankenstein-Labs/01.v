import Ajv from 'ajv/dist/2020';
import AjvFormats from 'ajv-formats';
import { safeLoad } from 'js-yaml';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EditorComponent, {
  DEFAULT_DEPENDENCY_FIREWALL_POLICY,
} from 'ee/security_orchestration/components/policy_editor/dependency_firewall/editor_component.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import {
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { DEPENDENCY_FIREWALL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { ASSIGNED_POLICY_PROJECT } from 'ee_jest/security_orchestration/mocks/mock_data';
import PolicySchema from '../../../../../../app/validators/json_schemas/security_orchestration_policy.json';

const mockExistingPolicy = {
  name: 'existing-dfw-policy',
  enabled: true,
  enforcement_type: 'enforced',
  rules: [{ type: 'license' }],
};

const mockExistingPolicyYaml = `dependency_firewall_policy:
  - name: existing-dfw-policy
    enabled: true
    enforcement_type: enforced
    rules:
      - type: license
`;

describe('DependencyFirewall EditorComponent', () => {
  let wrapper;

  const factory = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      propsData: {
        selectedPolicyType: DEPENDENCY_FIREWALL_POLICY_TYPE,
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockExistingPolicy, ...policy },
        isEditing: true,
      },
    });
  };

  const findEditorLayout = () => wrapper.findComponent(EditorLayout);

  describe('default state (new policy)', () => {
    beforeEach(() => {
      factory();
    });

    it('renders EditorLayout', () => {
      expect(findEditorLayout().exists()).toBe(true);
    });

    it('initializes with default YAML', () => {
      expect(findEditorLayout().props('yamlEditorValue')).toBe(DEFAULT_DEPENDENCY_FIREWALL_POLICY);
    });

    it('starts in YAML-only mode', () => {
      expect(findEditorLayout().props('defaultEditorMode')).toBe(EDITOR_MODE_YAML);
    });

    it('exposes only YAML mode option', () => {
      const modes = findEditorLayout().props('editorModes');
      expect(modes).toHaveLength(1);
      expect(modes[0].value).toBe(EDITOR_MODE_YAML);
    });

    it('passes correct loading state props', () => {
      expect(findEditorLayout().props('isEditing')).toBe(false);
      expect(findEditorLayout().props('isRemovingPolicy')).toBe(false);
      expect(findEditorLayout().props('isUpdatingPolicy')).toBe(false);
    });
  });

  describe('with existing policy', () => {
    beforeEach(() => {
      factoryWithExistingPolicy();
    });

    it('initializes YAML from existing policy', () => {
      expect(findEditorLayout().props('yamlEditorValue')).toBe(mockExistingPolicyYaml);
    });

    it('passes isEditing prop', () => {
      expect(findEditorLayout().props('isEditing')).toBe(true);
    });
  });

  describe('YAML update', () => {
    it('updates yamlEditorValue when update-yaml is emitted', async () => {
      factory();
      const newYaml = `dependency_firewall_policy:\n  - name: updated\n    enabled: false\n    enforcement_type: enforced\n    rules:\n      - type: license\n`;

      await findEditorLayout().vm.$emit('update-yaml', newYaml);

      expect(findEditorLayout().props('yamlEditorValue')).toBe(newYaml);
    });
  });

  describe('save flow', () => {
    it('emits save with correct action on save-policy', async () => {
      factory();
      findEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')).toHaveLength(1);
      expect(wrapper.emitted('save')[0][0]).toMatchObject({
        action: undefined,
      });
      expect(wrapper.emitted('save')[0][0].policy).toContain('type: dependency_firewall_policy');
    });

    it('emits save with REPLACE action when save-policy emits action', async () => {
      factoryWithExistingPolicy();
      findEditorLayout().vm.$emit('save-policy', SECURITY_POLICY_ACTIONS.REPLACE);
      await waitForPromises();

      expect(wrapper.emitted('save')[0][0]).toMatchObject({
        action: SECURITY_POLICY_ACTIONS.REPLACE,
      });
    });

    it('emits save with REMOVE action on remove-policy', async () => {
      factoryWithExistingPolicy();
      findEditorLayout().vm.$emit('remove-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')[0][0]).toMatchObject({
        action: SECURITY_POLICY_ACTIONS.REMOVE,
      });
    });
  });
});

describe('DEFAULT_DEPENDENCY_FIREWALL_POLICY', () => {
  // ajv cannot compile the full policy schema - an unrelated cron `pattern` in it is not a
  // valid unicode-mode regex - so validate against the `dependency_firewall_policy` subtree,
  // carrying `$defs` over for its `$ref`s. Strict mode is off because the schema declares
  // draft 2020-12 but still uses the draft-07 `additionalItems` keyword.
  const ajv = new Ajv({ strict: false, allowMatchingProperties: true });
  AjvFormats(ajv);
  const validate = ajv.compile({
    $schema: PolicySchema.$schema,
    $defs: PolicySchema.$defs,
    type: 'object',
    required: ['dependency_firewall_policy'],
    properties: {
      dependency_firewall_policy: PolicySchema.properties.dependency_firewall_policy,
    },
  });

  const parsed = () => safeLoad(DEFAULT_DEPENDENCY_FIREWALL_POLICY, { json: true });

  it('is valid against the security orchestration policy schema', () => {
    expect(parsed()).toValidateJsonSchema(validate);
  });

  it('offers all three dependency firewall rule types', () => {
    const { rules } = parsed().dependency_firewall_policy[0];

    expect(rules.map(({ type }) => type)).toEqual(['license', 'vulnerability', 'malicious']);
  });

  it('rejects a rule that omits both denied and allowed', () => {
    const policy = parsed();
    policy.dependency_firewall_policy[0].rules = [{ type: 'license' }];

    expect(policy).not.toValidateJsonSchema(validate);
  });
});
