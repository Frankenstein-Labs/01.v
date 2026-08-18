import { GlSegmentedControl } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import {
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
} from 'ee/security_orchestration/components/policy_editor/constants';
import YamlEditor from 'ee/security_orchestration/components/yaml_editor.vue';
import { SELECTION_CONFIG_CUSTOM } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

export const switchRuleMode = async (wrapper, mode, awaitPromise = true) => {
  await wrapper.findComponent(GlSegmentedControl).vm.$emit('input', mode);

  if (awaitPromise) {
    await waitForPromises();
  }
};

export const findYamlPreview = (wrapper) => wrapper.findByTestId('rule-editor-preview-content');
const findYamlEditor = (wrapper) => wrapper.findComponent(YamlEditor);

const verifyNoDisabledSectionsExist = (wrapper) =>
  expect(wrapper.findByTestId('disabled-section-overlay').exists()).toBe(false);

export const getYamlPreviewText = (wrapper) => findYamlPreview(wrapper).text();
export const normaliseYaml = (yaml) => yaml.replaceAll('\n', '');
export const verify = async ({ manifest, verifyRuleMode, wrapper }) => {
  verifyRuleMode();
  verifyNoDisabledSectionsExist(wrapper);
  expect(normaliseYaml(getYamlPreviewText(wrapper))).toBe(normaliseYaml(manifest));
  await switchRuleMode(wrapper, EDITOR_MODE_YAML);
  expect(findYamlEditor(wrapper).props('value')).toBe(manifest);
  await switchRuleMode(wrapper, EDITOR_MODE_RULE, false);

  expect(normaliseYaml(getYamlPreviewText(wrapper))).toBe(normaliseYaml(manifest));
  verifyNoDisabledSectionsExist(wrapper);
  verifyRuleMode();
};

export const createSppSubscriptionHandler = () =>
  jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectCreated: {
        project: {
          name: 'New project',
          fullPath: 'path/to/new-project',
          id: '01',
          branch: {
            rootRef: 'main',
          },
        },
        status: null,
        errors: [],
      },
    },
  });

export const navigateToCustomMode = async (wrapper) => {
  await wrapper
    .findComponentByTestId('enforcement-selection')
    .vm.$emit('input', SELECTION_CONFIG_CUSTOM);
};
