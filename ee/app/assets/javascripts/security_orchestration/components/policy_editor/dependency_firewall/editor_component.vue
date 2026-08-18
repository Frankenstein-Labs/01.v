<script>
import { s__ } from '~/locale';
import { extractPolicyContent, fromYaml } from 'ee/security_orchestration/components/utils';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { EDITOR_MODE_YAML, SECURITY_POLICY_ACTIONS } from '../constants';
import EditorLayout from '../editor_layout.vue';
import { DEPENDENCY_FIREWALL_POLICY_TYPE } from '../../constants';

export const DEFAULT_DEPENDENCY_FIREWALL_POLICY = `dependency_firewall_policy:
  - name: Your policy name
    description: Your policy description
    enabled: true
    # \`enforced\` blocks the download when a rule matches.
    # \`warn\` allows the download and records a warning.
    enforcement_type: warn
    policy_scope:
      projects:
        excluding: []
    rules:
      # Deny by SPDX license name. Swap \`denied\` for \`allowed\` to use an allowlist.
      - type: license
        denied:
          - name: SPDX License Name
        # Optional: exempt specific packages from this rule.
        # exceptions:
        #   - purl: pkg:npm/lodash@4.17.21
      # One severity threshold; anything at or above it is denied.
      # One of: critical, high, medium, low, info, unknown
      - type: vulnerability
        denied:
          - severity: high
        # Optional: exempt specific vulnerabilities from this rule.
        # exceptions:
        #   - id: CVE-2021-23337
      # Blocks packages flagged by the malicious packages feed.
      # \`denied\` only - \`allowed\` is not permitted for this type.
      - type: malicious
        denied:
          - is_malicious: true
`;

const YAML_ONLY_MODE = { value: EDITOR_MODE_YAML, text: s__('SecurityOrchestration|.yaml mode') };

export default {
  name: 'DependencyFirewallEditorComponent',
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  YAML_ONLY_MODES: [YAML_ONLY_MODE],
  i18n: {},
  components: {
    EditorLayout,
  },
  props: {
    existingPolicy: {
      type: Object,
      required: false,
      default: null,
    },
    isCreating: {
      type: Boolean,
      required: true,
    },
    isDeleting: {
      type: Boolean,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
    selectedPolicyType: {
      type: String,
      required: true,
    },
  },
  emits: ['save'],
  data() {
    const yamlEditorValue = this.existingPolicy
      ? policyToYaml(this.existingPolicy, this.selectedPolicyType)
      : DEFAULT_DEPENDENCY_FIREWALL_POLICY;

    const policy = fromYaml({ manifest: yamlEditorValue, type: DEPENDENCY_FIREWALL_POLICY_TYPE });

    return {
      policy,
      yamlEditorValue,
    };
  },
  methods: {
    async handleModifyPolicy(action) {
      const policy = extractPolicyContent({
        manifest: this.yamlEditorValue,
        type: this.selectedPolicyType,
        withType: true,
      });

      this.$emit('save', {
        action,
        policy: policyBodyToYaml(policy),
      });
    },
    handleUpdateYaml(manifest) {
      this.yamlEditorValue = manifest;
      this.policy = fromYaml({ manifest, type: DEPENDENCY_FIREWALL_POLICY_TYPE });
    },
  },
};
</script>
<template>
  <editor-layout
    :default-editor-mode="$options.EDITOR_MODE_YAML"
    :editor-modes="$options.YAML_ONLY_MODES"
    :is-editing="isEditing"
    :is-removing-policy="isDeleting"
    :is-updating-policy="isCreating"
    :policy="policy"
    :yaml-editor-value="yamlEditorValue"
    @remove-policy="handleModifyPolicy($options.SECURITY_POLICY_ACTIONS.REMOVE)"
    @save-policy="handleModifyPolicy"
    @update-yaml="handleUpdateYaml"
  />
</template>
