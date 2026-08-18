import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormInput } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemCustomFieldNumber from 'ee/work_items/components/work_item_custom_fields_number.vue';
import { newWorkItemId } from '~/work_items/utils';
import updateWorkItemCustomFieldsMutation from 'ee/work_items/graphql/update_work_item_custom_fields.mutation.graphql';
import { ENTER_KEY } from '~/lib/utils/keys';
import WorkItemSidebarWidget from '~/work_items/components/shared/work_item_sidebar_widget.vue';
import { CUSTOM_FIELDS_TYPE_NUMBER, CUSTOM_FIELDS_TYPE_TEXT } from '~/work_items/constants';
import { customFieldsWidgetResponseFactory } from 'jest/work_items/mock_data';

describe('WorkItemCustomFieldsNumber', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultWorkItemId = 'gid://gitlab/WorkItem/1';

  const defaultField = {
    customField: {
      id: '1-number',
      fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
      name: 'Number custom field label',
    },
    value: 5,
  };

  const mutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      workItemUpdate: {
        workItem: {
          id: defaultWorkItemId,
          widgets: [customFieldsWidgetResponseFactory],
        },
        errors: [],
      },
    },
  });

  const findEditButton = () => wrapper.findComponent('[data-testid="edit-button"]');
  const findInput = () => wrapper.findComponent(GlFormInput);
  const findValue = () => wrapper.find('[data-testid="custom-field-value"]');

  const createComponent = ({
    canUpdate = true,
    customField = defaultField,
    mutationHandler = mutationSuccessHandler,
    glFeatures = {},
  } = {}) => {
    wrapper = shallowMount(WorkItemCustomFieldNumber, {
      apolloProvider: createMockApollo([[updateWorkItemCustomFieldsMutation, mutationHandler]]),
      propsData: {
        canUpdate,
        customField,
        workItemType: 'Task',
        workItemId: defaultWorkItemId,
      },
      provide: {
        glFeatures,
      },
      stubs: {
        WorkItemSidebarWidget,
      },
    });
  };

  describe('rendering', () => {
    it('renders if custom field exists and type is correct', () => {
      createComponent();

      expect(wrapper.text()).toContain('Number custom field label');
    });

    it('does not render if custom field is empty', () => {
      createComponent({ customField: {} });

      expect(wrapper.text()).toContain('');
    });

    it('does not render if custom field type is incorrect', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-text',
            fieldType: CUSTOM_FIELDS_TYPE_TEXT,
            name: 'Text custom field label',
          },
          value: 'Sample text',
        },
      });

      expect(wrapper.text()).toContain('');
    });

    it('renders number input when editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();

      expect(findInput().attributes()).toMatchObject({
        min: '0',
        type: 'number',
      });
    });
  });

  describe('value', () => {
    it('shows value when number is set', () => {
      createComponent();

      expect(findValue().text()).toContain('5');
    });

    it('shows None when no number is set', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          value: null,
        },
      });

      expect(findValue().text()).toContain('None');
    });

    it('shows None when invalid value type is received', () => {
      createComponent({
        customField: {
          customField: {
            id: '1-number',
            fieldType: CUSTOM_FIELDS_TYPE_NUMBER,
            name: 'Number custom field label',
          },
          value: 'Text',
        },
      });

      expect(findValue().text()).toContain('None');
    });
  });

  describe('updating the value', () => {
    it('does not call "workItemUpdate" mutation when option is selected if is create flow', async () => {
      createComponent({ workItemId: newWorkItemId('Task') });
      await nextTick();

      const newValue = '10';

      await findEditButton().vm.$emit('click');
      findInput().vm.$emit('input', newValue);
      findInput().vm.$emit('blur');

      await waitForPromises();

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('sends mutation with correct variables when updating number', async () => {
      createComponent();
      const newValue = '10';

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', newValue);
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              numberValue: 10,
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    describe('when workItemFeaturesField feature flag is enabled', () => {
      it('passes useWorkItemFeatures as true to the mutation', async () => {
        createComponent({ glFeatures: { workItemFeaturesField: true } });
        const newValue = '10';

        findEditButton().vm.$emit('click');
        await nextTick();
        findInput().vm.$emit('input', newValue);
        findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

        expect(mutationSuccessHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            useWorkItemFeatures: true,
          }),
        );
      });
    });

    it('sends null when clearing the field', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', '');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              numberValue: null,
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    it('allows setting of decimal values', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', '-500.5');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          id: defaultWorkItemId,
          customFieldsWidget: [
            {
              customFieldId: defaultField.customField.id,
              numberValue: -500.5,
            },
          ],
        },
        useWorkItemFeatures: false,
      });
    });

    it('does not call mutation when the input value is the same', async () => {
      createComponent();

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', '5');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));

      expect(mutationSuccessHandler).not.toHaveBeenCalled();
    });

    it('emits error event when mutation returns an error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorMessage = 'Failed to update';
      const mutationHandler = jest.fn().mockResolvedValue({
        data: {
          workItemUpdate: {
            errors: [errorMessage],
          },
        },
      });

      createComponent({ mutationHandler });

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', '10');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('emits error event when mutation catches error', async () => {
      jest.spyOn(Sentry, 'captureException');

      const errorHandler = jest.fn().mockRejectedValue(new Error());

      createComponent({ mutationHandler: errorHandler });

      findEditButton().vm.$emit('click');
      await nextTick();
      findInput().vm.$emit('input', '200');
      findInput().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ENTER_KEY }));
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong while updating the Task. Please try again.'],
      ]);
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });
});
