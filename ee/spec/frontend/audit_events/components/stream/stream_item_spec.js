import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlToggle } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { STREAM_ITEMS_I18N, UPDATE_STREAM_MESSAGE } from 'ee/audit_events/constants';
import StreamItem from 'ee/audit_events/components/stream/stream_item.vue';
import StreamDestinationEditor from 'ee/audit_events/components/stream/stream_destination_editor.vue';

import groupAuditEventStreamingDestinationsUpdate from 'ee/audit_events/graphql/mutations/update_group_streaming_destination.mutation.graphql';
import instanceAuditEventStreamingDestinationsUpdate from 'ee/audit_events/graphql/mutations/update_instance_streaming_destination.mutation.graphql';

import { groupPath, instanceGroupPath } from '../../mock_data';
import { mockHttpTypeDestination } from '../../mock_data/consolidated_api';

jest.mock('~/alert');
jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('StreamItem', () => {
  let wrapper;
  let mutationHandlers;

  const groupPathProvide = groupPath;
  const itemProps = mockHttpTypeDestination[0];

  beforeEach(() => {
    mutationHandlers = {
      groupStreamingUpdate: jest.fn(),
      instanceStreamingUpdate: jest.fn(),
    };
  });

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    const apolloProvider = createMockApollo([
      [groupAuditEventStreamingDestinationsUpdate, mutationHandlers.groupStreamingUpdate],
      [instanceAuditEventStreamingDestinationsUpdate, mutationHandlers.instanceStreamingUpdate],
    ]);

    wrapper = mountExtended(StreamItem, {
      propsData: {
        item: itemProps,
        ...props,
      },
      provide: {
        groupPath: groupPathProvide,
        ...provide,
      },
      apolloProvider,
      stubs: {
        StreamDestinationEditor: true,
      },
    });
  };

  const findToggleButton = () => wrapper.findComponentByTestId('toggle-btn');
  const findToggle = () => wrapper.findComponent(GlToggle);
  const findStreamDestinationEditor = () => wrapper.findComponent(StreamDestinationEditor);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findFilterBadge = () => wrapper.findByTestId('filter-badge');

  describe('Group StreamItem', () => {
    beforeEach(async () => {
      createComponent({
        props: { item: mockHttpTypeDestination[0] },
      });
      await findToggleButton().vm.$emit('click');
    });

    it('should pass the item to the editor', () => {
      expect(findStreamDestinationEditor().props('item')).toStrictEqual(mockHttpTypeDestination[0]);
    });

    describe('active toggle', () => {
      it('renders toggle with correct state', () => {
        createComponent({
          props: { item: mockHttpTypeDestination[0] },
        });

        expect(findToggle().exists()).toBe(true);
        expect(findToggle().props('value')).toBe(true);
        expect(findToggle().props('label')).toBe('Active');
      });

      it('calls consolidated API mutation for group destinations', async () => {
        createComponent({
          props: { item: mockHttpTypeDestination[0] },
        });

        mutationHandlers.groupStreamingUpdate.mockResolvedValue({
          data: {
            groupAuditEventStreamingDestinationsUpdate: {
              errors: [],
            },
          },
        });

        await findToggle().vm.$emit('change', false);
        await waitForPromises();

        expect(mutationHandlers.groupStreamingUpdate).toHaveBeenCalledWith({
          input: expect.objectContaining({
            id: mockHttpTypeDestination[0].id,
            name: mockHttpTypeDestination[0].name,
            active: false,
            config: expect.any(Object),
          }),
        });
      });

      it('calls instance consolidated API mutation for instance destinations', async () => {
        createComponent({
          props: {
            item: {
              ...mockHttpTypeDestination[0],
              __typename: 'InstanceAuditEventStreamingDestination',
            },
          },
          provide: {
            groupPath: instanceGroupPath,
          },
        });

        mutationHandlers.instanceStreamingUpdate.mockResolvedValue({
          data: {
            instanceAuditEventStreamingDestinationsUpdate: {
              errors: [],
            },
          },
        });

        await findToggle().vm.$emit('change', true);
        await waitForPromises();

        expect(mutationHandlers.instanceStreamingUpdate).toHaveBeenCalledWith({
          input: expect.objectContaining({
            active: true,
          }),
        });
      });
    });

    describe('render', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not render the editor', () => {
        expect(findStreamDestinationEditor().isVisible()).toBe(false);
      });

      it('renders toggle with active state', () => {
        expect(findToggle().exists()).toBe(true);
        expect(findToggle().props('value')).toBe(true);
        expect(findToggle().props('label')).toBe('Active');
      });

      it('renders toggle with inactive state', () => {
        createComponent({
          props: {
            item: { ...mockHttpTypeDestination[0], active: false },
          },
        });

        expect(findToggle().props('value')).toBe(false);
        expect(findToggle().props('label')).toBe('Inactive');
      });

      it('applies opacity class when destination is inactive', () => {
        createComponent({
          props: {
            item: { ...mockHttpTypeDestination[0], active: false },
          },
        });

        expect(findToggleButton().classes()).toContain('gl-opacity-60');
      });

      it('does not apply opacity class when destination is active', () => {
        expect(findToggleButton().classes()).not.toContain('gl-opacity-60');
      });

      it.each`
        error                                                    | expectedResult
        ${new Error('Cannot activate destination due to limit')} | ${'Cannot activate destination due to limit'}
        ${new Error('Maximum number of destinations reached')}   | ${'Maximum number of destinations reached'}
        ${new Error('Some other error')}                         | ${'Failed to update destination status. Please try again.'}
      `(
        'shows specific error messages for activation limits: $expectedResult',
        async ({ error, expectedResult }) => {
          createComponent();

          mutationHandlers.groupStreamingUpdate.mockRejectedValue(error);

          await findToggle().vm.$emit('change', true);
          await waitForPromises();

          expect(Sentry.captureException).toHaveBeenCalledWith(error);
          expect(createAlert).toHaveBeenCalledWith({
            message: expectedResult,
            captureError: true,
            error,
          });
        },
      );
    });

    describe('deleting', () => {
      const id = 1;

      it('bubbles up the "deleted" event', async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');

        findStreamDestinationEditor().vm.$emit('deleted', id);

        expect(wrapper.emitted('deleted')).toEqual([[id]]);
      });
    });

    describe('editing', () => {
      beforeEach(async () => {
        createComponent();
        await findToggleButton().vm.$emit('click');
      });

      it('should pass the item to the editor', () => {
        expect(findStreamDestinationEditor().exists()).toBe(true);
        expect(findStreamDestinationEditor().props('item')).toStrictEqual(
          mockHttpTypeDestination[0],
        );
      });

      it('should emit the updated event and show success message when the editor fires its update event', async () => {
        await findStreamDestinationEditor().vm.$emit('updated');

        expect(findAlert().text()).toBe(UPDATE_STREAM_MESSAGE);
        expect(wrapper.emitted('updated')).toBeDefined();
        expect(findStreamDestinationEditor().exists()).toBe(true);
      });

      it('should emit the error event when the editor fires its error event', () => {
        findStreamDestinationEditor().vm.$emit('error');

        expect(wrapper.emitted('error')).toBeDefined();
        expect(findStreamDestinationEditor().exists()).toBe(true);
      });

      it('should close the editor when the editor fires its cancel event', async () => {
        findStreamDestinationEditor().vm.$emit('cancel');
        await waitForPromises();

        expect(findStreamDestinationEditor().isVisible()).toBe(false);
      });

      it('clears success message when closing', async () => {
        await findStreamDestinationEditor().vm.$emit('updated');
        await findToggleButton().vm.$emit('click');

        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('when an item has event filters', () => {
      beforeEach(() => {
        createComponent({
          props: { item: { ...mockHttpTypeDestination[0], eventTypeFilters: ['user_created'] } },
        });
      });

      it('should show filter badge', () => {
        expect(findFilterBadge().text()).toBe(STREAM_ITEMS_I18N.FILTER_BADGE_LABEL);
        expect(findFilterBadge().attributes('id')).toBe(mockHttpTypeDestination[0].id);
      });

      it('renders a popover', () => {
        expect(wrapper.findByTestId('filter-popover').element).toMatchSnapshot();
      });
    });

    describe('when an item has no filter', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: { ...mockHttpTypeDestination[0], eventTypeFilters: [], namespaceFilters: [] },
          },
        });
      });

      it('should not show filter badge', () => {
        expect(findFilterBadge().exists()).toBe(false);
      });
    });

    describe('state synchronization', () => {
      it('updates local state when item.active prop changes', async () => {
        createComponent();

        expect(findToggle().props('value')).toBe(true);

        await wrapper.setProps({
          item: { ...mockHttpTypeDestination[0], active: false },
        });

        expect(findToggle().props('value')).toBe(false);
      });
    });
  });
});
