import {
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
} from 'ee/security_orchestration/components/policy_editor/constants';

export const goToRuleMode = (findPolicyEditorLayout) =>
  findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_RULE);

export const goToYamlMode = (findPolicyEditorLayout) =>
  findPolicyEditorLayout().vm.$emit('update-editor-mode', EDITOR_MODE_YAML);
