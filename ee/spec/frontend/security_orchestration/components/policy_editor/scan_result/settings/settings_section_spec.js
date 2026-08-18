import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_EDITING_APPROVAL_RULES,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import SettingsItem from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_item.vue';

describe('SettingsSection', () => {
  let wrapper;

  const createSettings = ({ key, value }) => ({
    [key]: value,
  });

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(SettingsSection, {
      propsData,
      provide: {
        namespacePath: 'test-path',
        ...provide,
      },
    });
  };

  const findAllSettingsItem = () => wrapper.findAllComponents(SettingsItem);
  const findProtectedBranchesSettingsItem = () =>
    wrapper.findComponentByTestId('protected-branches-setting');
  const findMergeRequestSettingsItem = () => wrapper.findComponentByTestId('merge-request-setting');
  const findProjectWideSettingsItem = () => wrapper.findComponentByTestId('project-wide-setting');
  const findEmptyState = () => wrapper.findByTestId('empty-state');

  describe('rendering', () => {
    it('should render the empty message when no settings are provided', () => {
      createComponent();
      expect(findEmptyState().exists()).toBe(true);
    });

    it.each`
      description                                              | settings                                                                   | branchVisible | mergeRequestVisible | projectWideVisible
      ${`disable ${BLOCK_BRANCH_MODIFICATION} setting`}        | ${createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: false })}        | ${true}       | ${false}            | ${false}
      ${`enable ${BLOCK_BRANCH_MODIFICATION} setting`}         | ${createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true })}         | ${true}       | ${false}            | ${false}
      ${`enable ${PREVENT_PUSHING_AND_FORCE_PUSHING} setting`} | ${createSettings({ key: PREVENT_PUSHING_AND_FORCE_PUSHING, value: true })} | ${true}       | ${false}            | ${false}
      ${`disable ${PREVENT_APPROVAL_BY_AUTHOR} setting`}       | ${createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: false })}       | ${false}      | ${true}             | ${false}
      ${`enable ${PREVENT_APPROVAL_BY_AUTHOR} setting`}        | ${createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: true })}        | ${false}      | ${true}             | ${false}
      ${`disable ${PREVENT_EDITING_APPROVAL_RULES} setting`}   | ${createSettings({ key: PREVENT_EDITING_APPROVAL_RULES, value: false })}   | ${false}      | ${false}            | ${true}
      ${`enable ${PREVENT_EDITING_APPROVAL_RULES} setting`}    | ${createSettings({ key: PREVENT_EDITING_APPROVAL_RULES, value: true })}    | ${false}      | ${false}            | ${true}
    `('$description', ({ settings, branchVisible, mergeRequestVisible, projectWideVisible }) => {
      createComponent({ propsData: { settings } });
      expect(findProtectedBranchesSettingsItem().exists()).toBe(branchVisible);
      expect(findMergeRequestSettingsItem().exists()).toBe(mergeRequestVisible);
      expect(findProjectWideSettingsItem().exists()).toBe(projectWideVisible);
      expect(findAllSettingsItem().at(0).props('settings')).toEqual(settings);
      expect(findEmptyState().exists()).toBe(false);
    });

    it('renders all three enforcement-scope sections when settings span every scope', () => {
      createComponent({
        propsData: {
          settings: {
            ...createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true }),
            ...createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: true }),
            ...createSettings({ key: PREVENT_EDITING_APPROVAL_RULES, value: true }),
          },
        },
      });

      expect(findProtectedBranchesSettingsItem().exists()).toBe(true);
      expect(findMergeRequestSettingsItem().exists()).toBe(true);
      expect(findProjectWideSettingsItem().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);

      expect(findProtectedBranchesSettingsItem().props('link')).toBe(
        'http://test.host/test-path/-/settings/repository',
      );
      expect(findMergeRequestSettingsItem().props('link')).toBe(
        'http://test.host/test-path/-/settings/merge_requests',
      );
    });

    it('passes project-wide description and title to the project-wide section', () => {
      createComponent({
        propsData: {
          settings: createSettings({ key: PREVENT_EDITING_APPROVAL_RULES, value: true }),
        },
      });

      expect(findProjectWideSettingsItem().props('title')).toBe('Project-wide settings');
      expect(findProjectWideSettingsItem().props('description')).toBe(
        'Always applied while this policy is active, regardless of branches or violations.',
      );
    });

    it('groups merge request settings separately from project-wide settings', () => {
      createComponent({
        propsData: {
          settings: {
            ...createSettings({ key: PREVENT_APPROVAL_BY_AUTHOR, value: true }),
            ...createSettings({ key: PREVENT_EDITING_APPROVAL_RULES, value: true }),
          },
        },
      });

      expect(findMergeRequestSettingsItem().props('settings')).toEqual({
        [PREVENT_APPROVAL_BY_AUTHOR]: true,
      });
      expect(findProjectWideSettingsItem().props('settings')).toEqual({
        [PREVENT_EDITING_APPROVAL_RULES]: true,
      });
    });
  });

  describe('settings modification', () => {
    it('emits event when setting is toggled', async () => {
      createComponent({
        propsData: { settings: createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: true }) },
      });

      await findAllSettingsItem()
        .at(0)
        .vm.$emit('update', { key: BLOCK_BRANCH_MODIFICATION, value: false });
      expect(wrapper.emitted('changed')).toEqual([
        [createSettings({ key: BLOCK_BRANCH_MODIFICATION, value: false })],
      ]);
    });
  });
});
