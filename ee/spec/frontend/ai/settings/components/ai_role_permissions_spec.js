import { nextTick } from 'vue';
import { GlFormGroup, GlFormSelect } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiRolePermissions from 'ee/ai/settings/components/ai_role_permissions.vue';
import { ACCESS_LEVEL_EVERYONE_INTEGER } from 'ee/ai/settings/constants';
import {
  ACCESS_LEVEL_DEVELOPER_INTEGER,
  ACCESS_LEVEL_MAINTAINER_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  ACCESS_LEVEL_ADMIN_INTEGER,
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_REPORTER_INTEGER,
  ACCESS_LEVEL_PLANNER_INTEGER,
} from '~/access_level/constants';

describe('AiRolePermissions', () => {
  let wrapper;

  const findMainFormGroup = () => wrapper.findComponent(GlFormGroup);

  const findMinimumAccessLevelExecuteAsyncFormGroup = () =>
    wrapper.find('[label-for="minimum-access-level-execute-async-selector"]');
  const findMinimumAccessLevelExecuteSyncFormGroup = () =>
    wrapper.find('[label-for="minimum-access-level-execute-sync-selector"]');
  const findMinimumAccessLevelExecuteAsyncSelect = () =>
    wrapper.findComponentByTestId('minimum-access-level-execute-async-selector');
  const findMinimumAccessLevelExecuteSyncSelect = () =>
    wrapper.findComponentByTestId('minimum-access-level-execute-sync-selector');

  const createWrapper = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(AiRolePermissions, {
      propsData: {
        initialMinimumAccessLevelExecuteAsync: ACCESS_LEVEL_DEVELOPER_INTEGER,
        initialMinimumAccessLevelExecuteSync: ACCESS_LEVEL_GUEST_INTEGER,
        ...props,
      },
      provide: {
        isSaaS: true,
        ...provide,
      },
      stubs: {
        GlFormSelect,
        ...stubs,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the main form group with correct title', () => {
      expect(findMainFormGroup().attributes('label')).toBe('Access to GitLab Duo Agent Platform');
    });

    it('renders the section description', () => {
      createWrapper({ stubs: { GlFormGroup } });

      expect(findMainFormGroup().text()).toContain(
        'Control who can access AI-native features executed with or without CI/CD pipelines.',
      );
    });

    it('renders execute role form group with correct label', () => {
      const executeFormGroup = findMinimumAccessLevelExecuteSyncFormGroup();

      expect(executeFormGroup.attributes('label')).toBe('Features without CI/CD pipelines');
      expect(executeFormGroup.attributes('label-for')).toBe(
        'minimum-access-level-execute-sync-selector',
      );
    });

    it('renders execute async role form group with correct label', () => {
      const executeAsyncFormGroup = findMinimumAccessLevelExecuteAsyncFormGroup();

      expect(executeAsyncFormGroup.attributes('label')).toBe('Features with CI/CD pipelines');
      expect(executeAsyncFormGroup.attributes('label-for')).toBe(
        'minimum-access-level-execute-async-selector',
      );
    });
  });

  describe('execute async role selector', () => {
    it('renders with correct default options', () => {
      createWrapper();

      const expectedOptions = [
        { text: 'Developer', value: 30 },
        { text: 'Maintainer', value: 40 },
        { text: 'Owner', value: 50 },
      ];

      expect(findMinimumAccessLevelExecuteAsyncSelect().props('options')).toEqual(expectedOptions);
    });

    it('includes Admin role when isSaaS is false', () => {
      createWrapper({ provide: { isSaaS: false } });

      const expectedOptions = [
        { text: 'Developer', value: 30 },
        { text: 'Maintainer', value: 40 },
        { text: 'Owner', value: 50 },
        { text: 'Admin', value: 60 },
      ];

      expect(findMinimumAccessLevelExecuteAsyncSelect().props('options')).toEqual(expectedOptions);
    });

    it('displays value from initialMinimumAccessLevelExecuteAsync prop', () => {
      createWrapper({
        props: { initialMinimumAccessLevelExecuteAsync: ACCESS_LEVEL_MAINTAINER_INTEGER },
      });

      expect(findMinimumAccessLevelExecuteAsyncSelect().attributes('value')).toBe(
        String(ACCESS_LEVEL_MAINTAINER_INTEGER),
      );
    });

    it('emits role-change event when selection changes', () => {
      createWrapper();

      findMinimumAccessLevelExecuteAsyncSelect().vm.$emit(
        'change',
        ACCESS_LEVEL_MAINTAINER_INTEGER,
      );

      expect(wrapper.emitted('minimum-access-level-execute-async-change')).toEqual([
        [ACCESS_LEVEL_MAINTAINER_INTEGER],
      ]);
    });
  });

  describe('execute sync role selector', () => {
    it('renders with correct default options', () => {
      createWrapper();

      expect(findMinimumAccessLevelExecuteSyncSelect().props('options')).toEqual([
        { text: 'Everyone', value: ACCESS_LEVEL_EVERYONE_INTEGER },
        { text: 'Guest', value: ACCESS_LEVEL_GUEST_INTEGER },
        { text: 'Planner', value: ACCESS_LEVEL_PLANNER_INTEGER },
        { text: 'Reporter', value: ACCESS_LEVEL_REPORTER_INTEGER },
        { text: 'Developer', value: ACCESS_LEVEL_DEVELOPER_INTEGER },
        { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
        { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
      ]);
    });

    it('includes Admin role when isSaaS is false', () => {
      createWrapper({ provide: { isSaaS: false } });

      expect(findMinimumAccessLevelExecuteSyncSelect().props('options')).toEqual([
        { text: 'Everyone', value: ACCESS_LEVEL_EVERYONE_INTEGER },
        { text: 'Guest', value: ACCESS_LEVEL_GUEST_INTEGER },
        { text: 'Planner', value: ACCESS_LEVEL_PLANNER_INTEGER },
        { text: 'Reporter', value: ACCESS_LEVEL_REPORTER_INTEGER },
        { text: 'Developer', value: ACCESS_LEVEL_DEVELOPER_INTEGER },
        { text: 'Maintainer', value: ACCESS_LEVEL_MAINTAINER_INTEGER },
        { text: 'Owner', value: ACCESS_LEVEL_OWNER_INTEGER },
        { text: 'Admin', value: ACCESS_LEVEL_ADMIN_INTEGER },
      ]);
    });

    it('displays value from initialMinimumAccessLevelExecuteSync prop', () => {
      createWrapper({
        props: { initialMinimumAccessLevelExecuteSync: ACCESS_LEVEL_DEVELOPER_INTEGER },
      });

      expect(findMinimumAccessLevelExecuteSyncSelect().attributes('value')).toBe(
        String(ACCESS_LEVEL_DEVELOPER_INTEGER),
      );
    });

    it('emits role-change event when selection changes', () => {
      createWrapper();

      findMinimumAccessLevelExecuteSyncSelect().vm.$emit('change', ACCESS_LEVEL_REPORTER_INTEGER);

      expect(wrapper.emitted('minimum-access-level-execute-sync-change')).toEqual([
        [ACCESS_LEVEL_REPORTER_INTEGER],
      ]);
    });

    it('renders "Everyone" option in sync selector', () => {
      createWrapper();

      const options = findMinimumAccessLevelExecuteSyncSelect().props('options');
      const everyoneOption = options[0];

      expect(everyoneOption.text).toBe('Everyone');
      expect(everyoneOption.value).toBe(ACCESS_LEVEL_EVERYONE_INTEGER);
    });

    it('selects "Everyone" option correctly', async () => {
      createWrapper({
        props: { initialMinimumAccessLevelExecuteSync: -1 },
      });

      await nextTick();

      expect(findMinimumAccessLevelExecuteSyncSelect().attributes('value')).toBe('-1');
    });

    it('emits -1 when Everyone is selected', () => {
      createWrapper({
        props: { initialMinimumAccessLevelExecuteSync: ACCESS_LEVEL_DEVELOPER_INTEGER },
      });

      findMinimumAccessLevelExecuteSyncSelect().vm.$emit('change', -1);

      expect(wrapper.emitted('minimum-access-level-execute-sync-change')).toEqual([[-1]]);
    });

    it('emits number when role is selected', () => {
      createWrapper({ props: { initialMinimumAccessLevelExecuteSync: -1 } });

      findMinimumAccessLevelExecuteSyncSelect().vm.$emit('change', ACCESS_LEVEL_DEVELOPER_INTEGER);

      expect(wrapper.emitted('minimum-access-level-execute-sync-change')).toEqual([
        [ACCESS_LEVEL_DEVELOPER_INTEGER],
      ]);
    });
  });
});
