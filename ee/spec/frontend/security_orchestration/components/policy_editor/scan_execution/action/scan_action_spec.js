import { GlSprintf, GlCollapsibleListbox } from '@gitlab/ui';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyActionBuilder from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_action.vue';
import ProjectDastProfileSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/project_dast_profile_selector.vue';
import projectRunnerTags from 'ee/vue_shared/components/runner_tags_dropdown/graphql/get_project_runner_tags.query.graphql';
import groupRunnerTags from 'ee/vue_shared/components/runner_tags_dropdown/graphql/get_group_runner_tags.query.graphql';
import GroupDastProfileSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/group_dast_profile_selector.vue';
import RunnerTagsFilter from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/runner_tags_filter.vue';
import CiVariablesSelectors from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variables_selectors.vue';
import TemplateSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/template_selector.vue';
import ScanSettingsToggle from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/scan_settings_toggle.vue';
import { buildScannerAction } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  REPORT_TYPE_DAST,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
  REPORT_TYPE_API_FUZZING,
  REPORT_TYPE_COVERAGE_FUZZING,
} from '~/vue_shared/security_reports/constants';
import {
  DEFAULT_SCANNER,
  SCAN_EXECUTION_SCANNERS,
  SCANNER_HUMANIZED_TEMPLATE,
  SCANNER_HUMANIZED_TEMPLATE_ALT,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { createMockApolloProvider } from 'ee_jest/security_configuration/dast_profiles/graphql/create_mock_apollo_provider';
import { RUNNER_TAG_LIST_MOCK } from 'ee_jest/vue_shared/components/runner_tags_dropdown/mocks/mocks';
import {
  DEFAULT_TEMPLATE,
  LATEST_TEMPLATE,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/constants';

describe('PolicyActionBuilder', () => {
  let wrapper;
  let requestHandlers;
  const namespacePath = 'gid://gitlab/Project/20';
  const namespaceType = NAMESPACE_TYPES.PROJECT;
  const NEW_SCANNER = 'sast';
  const DEFAULT_ACTION = buildScannerAction({ scanner: DEFAULT_SCANNER });

  const defaultHandlerValue = (type = 'project') =>
    jest.fn().mockResolvedValue({
      data: {
        [type]: {
          id: namespacePath,
          runners: {
            nodes: RUNNER_TAG_LIST_MOCK,
          },
        },
      },
    });

  const createApolloProvider = (handlers) => {
    requestHandlers = handlers;
    return createMockApolloProvider([
      [projectRunnerTags, requestHandlers],
      [groupRunnerTags, requestHandlers],
    ]);
  };

  const factory = ({
    propsData = {},
    stubs = {},
    handlers = defaultHandlerValue(),
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(PolicyActionBuilder, {
      apolloProvider: createApolloProvider(handlers),
      propsData: {
        initAction: DEFAULT_ACTION,
        actionIndex: 0,
        ...propsData,
      },
      provide: {
        namespacePath,
        namespaceType,
        ...provide,
      },
      stubs: {
        SectionLayout,
        GlSprintf,
        ...stubs,
      },
    });
  };

  const findActionSeperator = () => wrapper.findByTestId('action-and-label');
  const findCiVariablesSelectors = () => wrapper.findComponent(CiVariablesSelectors);
  const findTemplateFilter = () => wrapper.findComponent(TemplateSelector);
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSprintf = () => wrapper.findComponent(GlSprintf);
  const findTagsFilter = () => wrapper.findComponent(RunnerTagsFilter);
  const findProjectDastSelector = () => wrapper.findComponent(ProjectDastProfileSelector);
  const findGroupDastSelector = () => wrapper.findComponent(GroupDastProfileSelector);
  const findAddVariableButton = () => wrapper.findComponentByTestId('add-variable-button');
  const findRemoveButton = () => wrapper.findComponentByTestId('remove-action');
  const findScanSettingsToggle = () => wrapper.findComponent(ScanSettingsToggle);

  it('renders default scanner', () => {
    factory();

    expect(findActionSeperator().exists()).toBe(false);
    expect(findDropdown().props()).toMatchObject({
      selected: DEFAULT_SCANNER,
      headerText: 'Select a scanner',
    });
  });

  it('only offers scanners a scan execution policy can run, excluding fuzzing', () => {
    factory();

    const offeredScanners = findDropdown()
      .props('items')
      .map(({ value }) => value);

    expect(offeredScanners).toEqual(Object.keys(SCAN_EXECUTION_SCANNERS));
    expect(offeredScanners).not.toContain(REPORT_TYPE_API_FUZZING);
    expect(offeredScanners).not.toContain(REPORT_TYPE_COVERAGE_FUZZING);
  });

  it.each`
    scanner                            | message
    ${REPORT_TYPE_DEPENDENCY_SCANNING} | ${SCANNER_HUMANIZED_TEMPLATE_ALT}
    ${REPORT_TYPE_CONTAINER_SCANNING}  | ${SCANNER_HUMANIZED_TEMPLATE_ALT}
    ${DEFAULT_SCANNER}                 | ${SCANNER_HUMANIZED_TEMPLATE}
  `('renders the action message correctly for $scanner', ({ scanner, message }) => {
    factory({
      propsData: { initAction: buildScannerAction({ scanner }) },
      stubs: { GlSprintf: true },
    });

    expect(findSprintf().attributes('message')).toBe(message);
  });

  it('renders the scanner action with the newly selected scanner', async () => {
    factory();
    await findDropdown().vm.$emit('select', NEW_SCANNER);

    expect(findActionSeperator().exists()).toBe(false);
    expect(findDropdown().props('selected')).toBe(NEW_SCANNER);
  });

  it('renders an additional action with the action seperator', () => {
    factory({ propsData: { actionIndex: 1 } });
    expect(findActionSeperator().exists()).toBe(true);
  });

  it('emits the "changed" event with existing tags when an action scan type is changed', async () => {
    factory({ propsData: { initAction: { ...DEFAULT_ACTION, tags: ['production'] } } });
    expect(wrapper.emitted('changed')).toBe(undefined);

    await findDropdown().vm.$emit('select', NEW_SCANNER);
    expect(wrapper.emitted('changed')).toStrictEqual([
      [{ ...buildScannerAction({ scanner: NEW_SCANNER }), tags: ['production'] }],
    ]);
  });

  it('removes the variables when a action scan type is changed', async () => {
    factory({ propsData: { initAction: { ...DEFAULT_ACTION, variables: { key: 'value' } } } });
    await findDropdown().vm.$emit('select', NEW_SCANNER);

    expect(wrapper.emitted('changed')).toStrictEqual([
      [buildScannerAction({ scanner: NEW_SCANNER })],
    ]);
  });

  it('emits the "removed" event when an action is changed', async () => {
    factory();
    expect(wrapper.emitted('remove')).toBe(undefined);

    await findRemoveButton().vm.$emit('click');
    expect(wrapper.emitted('remove')).toStrictEqual([[]]);
  });

  describe('scan filters', () => {
    describe('runner tags filter', () => {
      it('shows runner tags filter', () => {
        factory();

        expect(findTagsFilter().exists()).toBe(true);
      });

      it('emits the "changed" event when action tags are changed', async () => {
        factory({ propsData: { initAction: { ...DEFAULT_ACTION, tags: ['staging'] } } });
        expect(wrapper.emitted('changed')).toBe(undefined);

        const NEW_TAGS = ['main', 'release'];
        await findTagsFilter().vm.$emit('input', { tags: NEW_TAGS });
        expect(wrapper.emitted('changed')).toStrictEqual([[{ ...DEFAULT_ACTION, tags: NEW_TAGS }]]);
      });

      it('emits an error when filter encounters a parsing error', async () => {
        factory({ propsData: { initAction: { ...DEFAULT_ACTION, tags: ['staging'] } } });
        await findTagsFilter().vm.$emit('error');

        expect(wrapper.emitted('parsing-error')).toHaveLength(1);
      });

      it('removes the "tags" property when the filter emits the "remove" event', async () => {
        factory({ propsData: { initAction: { ...DEFAULT_ACTION, tags: ['staging'] } } });
        await findTagsFilter().vm.$emit('remove');

        expect(wrapper.emitted('changed')).toStrictEqual([[DEFAULT_ACTION]]);
      });
    });

    describe('template filter', () => {
      it('renders', () => {
        factory();
        expect(findTemplateFilter().exists()).toBe(true);
      });

      it('emits "changed" with the updated value when updated', () => {
        factory({
          propsData: {
            initAction: {
              ...DEFAULT_ACTION,
              template: LATEST_TEMPLATE,
            },
          },
        });
        findTemplateFilter().vm.$emit('input', { template: DEFAULT_TEMPLATE });
        expect(wrapper.emitted('changed')).toEqual([
          [{ ...DEFAULT_ACTION, template: DEFAULT_TEMPLATE }],
        ]);
      });

      it('emits "changed" with the updated value when removed', () => {
        factory({
          propsData: {
            initAction: {
              ...DEFAULT_ACTION,
              template: LATEST_TEMPLATE,
            },
          },
        });
        findTemplateFilter().vm.$emit('remove');
        expect(wrapper.emitted('changed')).toEqual([[{ ...DEFAULT_ACTION }]]);
      });
    });

    describe('ci variable filter', () => {
      it('initially hides ci variable filter', () => {
        factory();
        expect(findCiVariablesSelectors().exists()).toBe(false);
      });

      it('emits "changed" with the updated variable when a variable is updated', () => {
        const VARIABLES = { key: 'new key', value: 'new value' };

        factory({
          propsData: {
            initAction: {
              ...DEFAULT_ACTION,
              variables: { [VARIABLES.key]: VARIABLES.value },
            },
            variables: { test: 'test_value' },
          },
        });
        const NEW_VARIABLES = { '': '' };
        findCiVariablesSelectors().vm.$emit('input', { variables: NEW_VARIABLES });
        expect(wrapper.emitted('changed')).toEqual([
          [{ ...DEFAULT_ACTION, variables: NEW_VARIABLES }],
        ]);
      });
    });

    describe('scan filter selector', () => {
      beforeEach(() => {
        factory();
      });

      it('displays the add variable button', () => {
        expect(findAddVariableButton().exists()).toBe(true);
        expect(findAddVariableButton().attributes().disabled === undefined).toBe(true);
      });

      it('displays the ci variable filter when the scan filter selector selects it', async () => {
        await findAddVariableButton().vm.$emit('click');

        expect(findAddVariableButton().exists()).toBe(false);
        expect(findCiVariablesSelectors().exists()).toBe(true);
      });

      it('hides the ci variable filter if action has variables', () => {
        factory({ propsData: { initAction: { ...DEFAULT_ACTION, variables: { key: 'value' } } } });
        expect(findAddVariableButton().exists()).toBe(false);
      });
    });

    describe('scan settings toggle', () => {
      it('renders the scan settings toggle', () => {
        factory();
        expect(findScanSettingsToggle().exists()).toBe(true);
      });

      it('passes selected=false when scan_settings is not defined', () => {
        factory();
        expect(findScanSettingsToggle().props('selected')).toBe(false);
      });

      it('passes selected=true when scan_settings.ignore_default_before_after_script is true', () => {
        factory({
          propsData: {
            initAction: {
              ...DEFAULT_ACTION,
              scan_settings: { ignore_default_before_after_script: true },
            },
          },
        });
        expect(findScanSettingsToggle().props('selected')).toBe(true);
      });

      it('emits "changed" with scan_settings when toggle is enabled', () => {
        factory();
        findScanSettingsToggle().vm.$emit('input', {
          scan_settings: { ignore_default_before_after_script: true },
        });
        expect(wrapper.emitted('changed')).toEqual([
          [{ ...DEFAULT_ACTION, scan_settings: { ignore_default_before_after_script: true } }],
        ]);
      });

      it('emits "changed" without scan_settings when toggle is disabled', () => {
        factory({
          propsData: {
            initAction: {
              ...DEFAULT_ACTION,
              scan_settings: { ignore_default_before_after_script: true },
            },
          },
        });
        findScanSettingsToggle().vm.$emit('remove');
        expect(wrapper.emitted('changed')).toEqual([[DEFAULT_ACTION]]);
      });
    });
  });

  describe('switching between group and project namespace', () => {
    it.each`
      namespaceTypeValue         | projectSelectorExist | groupSelectorExist
      ${NAMESPACE_TYPES.PROJECT} | ${true}              | ${false}
      ${NAMESPACE_TYPES.GROUP}   | ${false}             | ${true}
    `(
      'should display correct selector based on namespace type for DAST scan',
      ({ namespaceTypeValue, projectSelectorExist, groupSelectorExist }) => {
        factory({
          propsData: { initAction: { ...DEFAULT_ACTION, scan: REPORT_TYPE_DAST } },
          provide: { namespaceType: namespaceTypeValue },
        });

        expect(findProjectDastSelector().exists()).toBe(projectSelectorExist);
        expect(findGroupDastSelector().exists()).toBe(groupSelectorExist);
      },
    );
  });
});
