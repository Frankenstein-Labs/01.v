import { nextTick } from 'vue';
import { GlTable, GlFormCheckbox, GlFormGroup, GlLink, GlButton } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiNamespaceAccessRules from 'ee/ai/settings/components/ai_namespace_access_rules.vue';
import GroupSelector from 'ee/ai/settings/components/group_selector.vue';

describe('AiNamespaceAccessRules', () => {
  let wrapper;

  const emptyDefaultRow = { throughNamespace: null, features: [] };

  const mockNamespaceAccessRules = [
    {
      throughNamespace: {
        id: 1,
        name: 'Group A',
        fullPath: 'group-a',
      },
      features: ['duo_agent_platform'],
    },
    {
      throughNamespace: {
        id: 2,
        name: 'Group B',
        fullPath: 'group-b',
      },
      features: ['duo_classic'],
    },
  ];

  const createComponent = ({ props = {}, mountFn = shallowMountExtended, stubs = {} } = {}) => {
    wrapper = mountFn(AiNamespaceAccessRules, {
      propsData: {
        initialNamespaceAccessRules: mockNamespaceAccessRules,
        ...props,
      },
      stubs: {
        GroupSelector: true,
        ...stubs,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findTable = () => wrapper.findComponent(GlTable);
  const findNamespaceLinks = () =>
    wrapper
      .find('table')
      .findAllComponents(GlLink)
      .filter((link) => link.attributes('target') === '_blank');
  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findGroupSelector = () => wrapper.findComponent(GroupSelector);
  const findRemoveButtons = () =>
    wrapper.findAllComponents(GlButton).wrappers.filter((btn) => btn.text() === 'Remove');

  describe('when access rules array is empty', () => {
    beforeEach(() => {
      createComponent({ props: { initialNamespaceAccessRules: [] }, mountFn: mountExtended });
    });

    it('does not render the table', () => {
      expect(findTable().exists()).toBe(false);
    });
  });

  describe('when initialNamespaceAccessRules is provided', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('renders the form group with correct label', () => {
      expect(findFormGroup().text()).toContain('Restrict access based on group membership');
    });

    it('renders the help text', () => {
      expect(wrapper.text()).toContain(
        'Restrict access to GitLab Duo. By default, all eligible users can access all configured AI features.',
      );
    });

    it('renders the table with access rules data plus default row', () => {
      const expectedItems = [...mockNamespaceAccessRules, emptyDefaultRow];
      expect(findTable().props('items')).toEqual(expectedItems);
    });

    it('renders the table with correct fields', () => {
      expect(findTable().props('fields')).toEqual([
        {
          key: 'namespaceName',
          label: 'Members of group',
          thStyle: { width: '40%' },
          tdClass: 'gl-max-w-0',
        },
        {
          key: 'features',
          label: 'Have access to',
          thStyle: { width: '40%' },
          tdClass: 'gl-max-w-0',
        },
        {
          key: 'actions',
          label: null,
          thStyle: { width: '20%' },
          tdClass: 'gl-max-w-0',
        },
      ]);
    });

    describe('namespace links', () => {
      it('renders namespace links with correct href and text', () => {
        const links = findNamespaceLinks();

        expect(links.at(0).attributes('href')).toBe('/group-a');
        expect(links.at(0).text()).toBe('Group A');

        expect(links.at(1).attributes('href')).toBe('/group-b');
        expect(links.at(1).text()).toBe('Group B');
      });
    });

    describe('enabled features checkboxes', () => {
      it('renders checkbox for all features for each rule', () => {
        const checkboxes = findCheckboxes();
        expect(checkboxes).toHaveLength(6);
      });

      it('renders checkbox labels for all available features', () => {
        const checkboxes = findCheckboxes();

        expect(checkboxes.at(0).text()).toBe('GitLab Duo');
        expect(checkboxes.at(1).text()).toBe('GitLab Duo Agent Platform');
      });

      it('checks the correct checkboxes based on configuration', () => {
        const checkboxes = findCheckboxes();

        expect(checkboxes.at(0).props('checked')).toBe(false);
        expect(checkboxes.at(1).props('checked')).toBe(true);

        expect(checkboxes.at(2).props('checked')).toBe(true);
        expect(checkboxes.at(3).props('checked')).toBe(false);
      });
    });

    describe('remove namespace access rule', () => {
      it('removes the namespace access rule with matching id', async () => {
        expect(findTable().props('items')).toHaveLength(3);

        await findRemoveButtons().at(0).trigger('click');
        await nextTick();

        const items = findTable().props('items');

        expect(items).toHaveLength(2);
        expect(items).toEqual([mockNamespaceAccessRules[1], emptyDefaultRow]);
      });

      it('emits change event with updated namespace access rules', async () => {
        await findRemoveButtons().at(1).trigger('click');

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([mockNamespaceAccessRules[0]]);
      });
    });

    describe('when feature is toggled', () => {
      it('enables feature for specific namespace access rule', async () => {
        await findCheckboxes().at(0).vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([
          {
            throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
            features: ['duo_agent_platform', 'duo_classic'], // Now has both features
          },
          {
            throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
            features: ['duo_classic'],
          },
        ]);
      });

      it('disables feature for specific namespace access rule', async () => {
        await findCheckboxes().at(1).vm.$emit('change', false);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([
          {
            throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
            features: [],
          },
          {
            throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
            features: ['duo_classic'],
          },
        ]);
      });

      it('de-duplicates features for namespace access rules', async () => {
        await findCheckboxes().at(1).vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toEqual([
          {
            throughNamespace: { id: 1, name: 'Group A', fullPath: 'group-a' },
            features: ['duo_agent_platform'],
          },
          {
            throughNamespace: { id: 2, name: 'Group B', fullPath: 'group-b' },
            features: ['duo_classic'],
          },
        ]);
      });
    });

    describe('default row behavior', () => {
      it('renders a default row with "All eligible users" label and no remove button', () => {
        const tableText = wrapper.find('table').text();
        expect(tableText).toContain('All eligible users');

        const removeButtons = findRemoveButtons();
        expect(removeButtons).toHaveLength(2);
      });

      it('adds global rule when toggling features on the default row', async () => {
        await findCheckboxes().at(4).vm.$emit('change', true);
        await nextTick();

        expect(wrapper.emitted('change')).toHaveLength(1);
        const [[emittedRules]] = wrapper.emitted('change');
        expect(emittedRules).toHaveLength(3);

        expect(emittedRules).toContainEqual({
          throughNamespace: null,
          features: ['duo_classic'],
        });
      });
    });
  });

  describe('when disabledCheckbox is true', () => {
    beforeEach(() => {
      createComponent({ props: { disabledCheckbox: true }, mountFn: mountExtended });
    });

    it('disables all feature checkboxes', () => {
      findCheckboxes().wrappers.forEach((checkbox) => {
        expect(checkbox.props('disabled')).toBe(true);
      });
    });

    it('disables all remove buttons', () => {
      findRemoveButtons().forEach((button) => {
        expect(button.props('disabled')).toBe(true);
      });
    });

    it('passes disabled to the group selector', () => {
      expect(findGroupSelector().props('disabled')).toBe(true);
    });
  });

  describe('GroupSelector', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('adds new namespace to access rules when namespace is selected', async () => {
      const namespace1 = {
        id: 'gid://gitlab/Group/9',
        name: 'Group C',
        fullPath: 'group-c',
      };

      const namespace2 = {
        id: 'gid://gitlab/Group/10',
        name: 'Group D',
        fullPath: 'group-d',
      };

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();
      findGroupSelector().vm.$emit('group-selected', namespace2);
      await nextTick();

      const links = findNamespaceLinks();
      const checkboxes = findCheckboxes();

      expect(links).toHaveLength(4);

      expect(links.at(2).attributes('href')).toBe('/group-c');
      expect(links.at(2).text()).toBe('Group C');

      expect(checkboxes.at(4).props('checked')).toBe(true);
      expect(checkboxes.at(5).props('checked')).toBe(true);

      expect(links.at(3).attributes('href')).toBe('/group-d');
      expect(links.at(3).text()).toBe('Group D');
    });

    it('skips new namespace when namespace is already added', async () => {
      const namespace1 = {
        id: 'gid://gitlab/Group/9',
        name: 'Group C',
        fullPath: 'group-c',
      };

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();

      expect(findNamespaceLinks()).toHaveLength(3);

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();

      expect(findNamespaceLinks()).toHaveLength(3);
    });

    it('emits namespace access rules when namespace is added', async () => {
      const namespace1 = {
        id: 'gid://gitlab/Group/3',
        name: 'Group C',
        fullPath: 'group-c',
      };

      findGroupSelector().vm.$emit('group-selected', namespace1);
      await nextTick();

      expect(wrapper.emitted('change')[0][0]).toEqual([
        {
          features: ['duo_agent_platform'],
          throughNamespace: {
            fullPath: 'group-a',
            id: 1,
            name: 'Group A',
          },
        },
        {
          features: ['duo_classic'],
          throughNamespace: {
            fullPath: 'group-b',
            id: 2,
            name: 'Group B',
          },
        },
        {
          features: ['duo_classic', 'duo_agent_platform'],
          throughNamespace: {
            fullPath: 'group-c',
            id: 3,
            name: 'Group C',
          },
        },
      ]);
    });
  });
});
