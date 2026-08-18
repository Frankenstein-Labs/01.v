import { GlCard, GlCollapsibleListbox, GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import EventActionsConfiguration from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/event_configurations/event_actions_configuration.vue';

describe('EventActionsConfiguration', () => {
  let wrapper;

  const mockScope = 'merge_request';
  const mockField = 'action';
  const mockFeatureFlaggedAction = {
    text: 'Approved',
    value: 'approved',
    featureFlag: 'someFeatureFlag',
  };
  const mockPlainAction = { text: 'Merged', value: 'merged' };
  const mockActions = [mockFeatureFlaggedAction, mockPlainAction];

  const createFilterMock = (values) => ({
    [mockScope]: { rules: [{ field: mockField, operator: 'in', value: values }] },
  });

  const createWrapper = ({ props = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(EventActionsConfiguration, {
      propsData: {
        scope: mockScope,
        field: mockField,
        actions: mockActions,
        listboxHeaderText: 'Listbox header',
        ...props,
      },
      provide: {
        glFeatures: {
          someFeatureFlag: true,
          ...glFeatures,
        },
      },
      stubs: {
        GlCard: stubComponent(GlCard, {
          template: '<div><slot name="header"></slot><slot></slot></div>',
        }),
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  describe('action options', () => {
    describe('when feature flag is on', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('renders flagged actions and all unflagged actions', () => {
        expect(findListbox().props('items')).toEqual([
          { text: 'Approved', value: 'approved' },
          { text: 'Merged', value: 'merged' },
        ]);
      });
    });

    describe('when feature flag is off', () => {
      beforeEach(() => {
        createWrapper({ glFeatures: { someFeatureFlag: false } });
      });

      it('omits the flagged action', () => {
        expect(findListbox().props('items')).toEqual([{ text: 'Merged', value: 'merged' }]);
      });
    });
  });

  describe('toggle text', () => {
    it('falls back to the listbox header when nothing is selected', () => {
      createWrapper();

      expect(findListbox().props('toggleText')).toBe('Listbox header');
    });

    describe('when actions are selected', () => {
      beforeEach(() => {
        const approvedAndMergedFilter = createFilterMock(['approved', 'merged']);
        createWrapper({ props: { value: approvedAndMergedFilter } });
      });

      it('joins the selected action labels', () => {
        expect(findListbox().props('toggleText')).toBe('Approved, Merged');
      });
    });
  });

  describe('display props', () => {
    it('forwards the listbox header text', () => {
      createWrapper();

      expect(findListbox().props('headerText')).toBe('Listbox header');
    });
  });

  describe('selection', () => {
    describe('when an action is selected', () => {
      beforeEach(() => {
        createWrapper({ props: { value: {} } });
      });

      it('emits input with the scoped action filter', async () => {
        const approvedFilter = createFilterMock(['approved']);
        await findListbox().vm.$emit('select', ['approved']);

        expect(wrapper.emitted('input')).toEqual([[approvedFilter]]);
      });
    });

    describe('when no action is selected', () => {
      beforeEach(() => {
        const approvedFilter = createFilterMock(['approved']);
        createWrapper({ props: { value: approvedFilter } });
      });

      it('drops the scope from the emitted value', async () => {
        await findListbox().vm.$emit('select', []);

        expect(wrapper.emitted('input')).toEqual([[{}]]);
      });
    });

    it('preserves other scopes when updating its own', async () => {
      createWrapper({ props: { value: { pipeline_hooks: { rules: [] } } } });

      await findListbox().vm.$emit('select', ['approved']);

      const approvedFilter = createFilterMock(['approved']);
      expect(wrapper.emitted('input')).toEqual([
        [{ pipeline_hooks: { rules: [] }, ...approvedFilter }],
      ]);
    });
  });

  describe('invalidFeedback', () => {
    describe('when no feedback is given', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('keeps the form group and listbox valid', () => {
        expect(findFormGroup().attributes('invalid-feedback')).toBeUndefined();
        expect(findListbox().props('state')).toBe(true);
      });
    });

    describe('when feedback is given', () => {
      beforeEach(() => {
        createWrapper({ props: { invalidFeedback: 'Select at least one action.' } });
      });

      it('forwards the feedback message and marks the listbox invalid', () => {
        expect(findFormGroup().attributes('invalid-feedback')).toBe('Select at least one action.');
        expect(findListbox().props('state')).toBe(false);
      });
    });
  });
});
