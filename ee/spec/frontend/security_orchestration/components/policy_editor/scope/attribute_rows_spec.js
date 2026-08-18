import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AttributeRows from 'ee/security_orchestration/components/policy_editor/scope/attribute_rows.vue';
import AttributeSelector from 'ee/security_orchestration/components/policy_editor/scope/attribute_selector.vue';

describe('AttributeRows', () => {
  let wrapper;

  const createComponent = (mountOptions = {}) => {
    wrapper = shallowMountExtended(AttributeRows, {
      ...mountOptions,
    });
  };

  const findRows = () => wrapper.findAllByTestId('scope-attribute-row');
  const findSelectors = () => wrapper.findAllComponents(AttributeSelector);
  const findAddRowButton = () => wrapper.findComponentByTestId('add-row');
  const findRemoveButtons = () => wrapper.findAllComponentsByTestId('remove-row');
  const findFirstSelector = () => findSelectors().at(0);
  const findExperimentNotice = () => wrapper.findByTestId('experiment-notice');

  describe('initial rendering', () => {
    it('renders a single empty row when policyScope is empty', () => {
      createComponent();

      expect(findRows()).toHaveLength(1);
      expect(findFirstSelector().props('policyScope')).toEqual({});
    });

    it('renders the experiment notice banner', () => {
      createComponent();

      expect(findExperimentNotice().exists()).toBe(true);
      expect(findExperimentNotice().text()).toContain('Only the four built-in security categories');
    });

    it('hydrates one row per non-reserved key in policyScope', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: { excluding: [] },
            business_impact: { including: [{ id: 1 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });

      expect(findRows()).toHaveLength(2);
      expect(findSelectors().at(0).props('policyScope')).toEqual({
        business_impact: { including: [{ id: 1 }] },
      });
      expect(findSelectors().at(1).props('policyScope')).toEqual({
        exposure: { including: [{ id: 3 }] },
      });
    });
  });

  describe('disabledCategoryKeys', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          policyScope: {
            business_impact: { including: [{ id: 1 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });
    });

    it('disables a row’s own selected key in every other row', () => {
      expect(findSelectors().at(0).props('disabledCategoryKeys')).toEqual(['exposure']);
      expect(findSelectors().at(1).props('disabledCategoryKeys')).toEqual(['business_impact']);
    });

    it('excludes empty (unselected) rows from the disabled list', async () => {
      await findAddRowButton().vm.$emit('click');

      expect(findSelectors().at(2).props('disabledCategoryKeys')).toEqual([
        'business_impact',
        'exposure',
      ]);
    });

    it('recomputes disabled keys when a row changes category', async () => {
      findSelectors()
        .at(0)
        .vm.$emit('changed', { new_category: { including: [] } });
      await nextTick();

      expect(findSelectors().at(1).props('disabledCategoryKeys')).toEqual(['new_category']);
    });
  });

  describe('add row', () => {
    it('appends an empty row when the Add button is clicked', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      expect(findRows()).toHaveLength(1);

      await findAddRowButton().vm.$emit('click');

      expect(findRows()).toHaveLength(2);
      expect(findSelectors().at(1).props('policyScope')).toEqual({});
    });

    it('disables the Add button while any row is empty', async () => {
      createComponent();

      expect(findAddRowButton().props('disabled')).toBe(true);

      findSelectors()
        .at(0)
        .vm.$emit('changed', { business_impact: { including: [] } });
      await nextTick();

      expect(findAddRowButton().props('disabled')).toBe(false);
    });

    it('disables the Add button when the disabled prop is true', () => {
      createComponent({
        propsData: {
          disabled: true,
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      expect(findAddRowButton().props('disabled')).toBe(true);
    });

    it('disables the Add button once every available category has a row', async () => {
      createComponent({
        propsData: {
          policyScope: {
            business_impact: { including: [{ id: 1 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });

      findSelectors().at(0).vm.$emit('categories-loaded', 2);
      await nextTick();

      expect(findAddRowButton().props('disabled')).toBe(true);
    });

    it('keeps the Add button enabled while fewer rows than available categories exist', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      findSelectors().at(0).vm.$emit('categories-loaded', 4);
      await nextTick();

      expect(findAddRowButton().props('disabled')).toBe(false);
    });
  });

  describe('row labels', () => {
    it('renders a 1-based, row-specific aria-label on each Remove button', () => {
      createComponent({
        propsData: {
          policyScope: {
            business_impact: { including: [{ id: 1 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });

      const buttons = findRemoveButtons();
      expect(buttons.at(0).attributes('aria-label')).toBe('Remove row 1');
      expect(buttons.at(1).attributes('aria-label')).toBe('Remove row 2');
    });
  });

  describe('remove row', () => {
    it('removes a row and emits the updated aggregate without that category key', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: { excluding: [] },
            business_impact: { including: [{ id: 1 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });

      await findRemoveButtons().at(0).vm.$emit('click');

      const payload = wrapper.emitted('changed').at(-1)[0];
      expect(payload).toEqual({
        projects: { excluding: [] },
        exposure: { including: [{ id: 3 }] },
      });
      expect(payload).not.toHaveProperty('business_impact');
      expect(findRows()).toHaveLength(1);
    });

    it('hides the remove button when only one row is rendered', () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      expect(findRows()).toHaveLength(1);
      expect(findRemoveButtons()).toHaveLength(0);
    });

    it('shows the remove button on every row once a second row is added', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      await findAddRowButton().vm.$emit('click');

      expect(findRows()).toHaveLength(2);
      expect(findRemoveButtons()).toHaveLength(2);
    });
  });

  describe('aggregate changed emits', () => {
    it('merges reserved keys with every row’s payload', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: { excluding: [{ id: 9 }] },
            business_impact: { including: [{ id: 1 }] },
          },
        },
      });

      findSelectors()
        .at(0)
        .vm.$emit('changed', {
          business_impact: { including: [{ id: 1 }, { id: 2 }] },
        });

      expect(wrapper.emitted('changed').at(-1)[0]).toEqual({
        projects: { excluding: [{ id: 9 }] },
        business_impact: { including: [{ id: 1 }, { id: 2 }] },
      });
    });

    it('produces a scope with two category keys when two rows are filled', async () => {
      createComponent();

      findSelectors()
        .at(0)
        .vm.$emit('changed', { business_impact: { including: [] } });
      await nextTick();

      await findAddRowButton().vm.$emit('click');

      findSelectors()
        .at(1)
        .vm.$emit('changed', { exposure: { including: [{ id: 3 }] } });

      expect(wrapper.emitted('changed').at(-1)[0]).toEqual({
        business_impact: { including: [] },
        exposure: { including: [{ id: 3 }] },
      });
    });
  });

  describe('error forwarding', () => {
    it('re-emits errors from any row', () => {
      createComponent();

      findSelectors().at(0).vm.$emit('error', 'oops');

      expect(wrapper.emitted('error')).toEqual([['oops']]);
    });
  });

  describe('external policyScope changes', () => {
    it('rebuilds rows when the parent replaces policyScope with a different set of categories', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      expect(findRows()).toHaveLength(1);
      expect(findSelectors().at(0).props('policyScope')).toEqual({
        business_impact: { including: [{ id: 1 }] },
      });

      await wrapper.setProps({
        policyScope: {
          business_impact: { including: [{ id: 1 }] },
          exposure: { including: [{ id: 3 }] },
        },
      });

      expect(findRows()).toHaveLength(2);
      expect(findSelectors().at(1).props('policyScope')).toEqual({
        exposure: { including: [{ id: 3 }] },
      });
    });

    it('rebuilds rows when a category’s including ids change externally on the same set of keys', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      await wrapper.setProps({
        policyScope: { business_impact: { including: [{ id: 7 }, { id: 8 }] } },
      });

      expect(findSelectors().at(0).props('policyScope')).toEqual({
        business_impact: { including: [{ id: 7 }, { id: 8 }] },
      });
    });

    it('does not rebuild rows when the round-tripped policyScope matches the current aggregate', async () => {
      createComponent({
        propsData: {
          policyScope: { business_impact: { including: [{ id: 1 }] } },
        },
      });

      const originalInstance = findSelectors().at(0).vm;

      await wrapper.setProps({
        policyScope: { business_impact: { including: [{ id: 1 }] } },
      });

      expect(findSelectors().at(0).vm).toBe(originalInstance);
    });

    it('ignores reserved-key-only changes when deciding whether to rebuild', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: { excluding: [{ id: 1 }] },
            business_impact: { including: [{ id: 1 }] },
          },
        },
      });

      const originalInstance = findSelectors().at(0).vm;

      await wrapper.setProps({
        policyScope: {
          projects: { excluding: [{ id: 2 }] },
          business_impact: { including: [{ id: 1 }] },
        },
      });

      expect(findSelectors().at(0).vm).toBe(originalInstance);
    });
  });

  describe('prop forwarding', () => {
    it('forwards disabled and isDirty to every row', () => {
      createComponent({
        propsData: {
          disabled: true,
          isDirty: true,
          policyScope: {
            business_impact: { including: [{ id: 1 }] },
            exposure: { including: [{ id: 3 }] },
          },
        },
      });

      findSelectors().wrappers.forEach((selector) => {
        expect(selector.props('disabled')).toBe(true);
        expect(selector.props('isDirty')).toBe(true);
      });
    });
  });
});
