import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import ValueStreamSelect from 'ee/analytics/cycle_analytics/components/value_stream_select.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { dismissGlobalAlertById } from '~/lib/utils/global_alerts';
import { valueStreams, newValueStreamPath, editValueStreamPath } from '../mock_data';

jest.mock('~/lib/utils/global_alerts', () => ({
  dismissGlobalAlertById: jest.fn(),
}));

Vue.use(Vuex);

describe('ValueStreamSelect', () => {
  let wrapper = null;
  let trackingSpy = null;

  const deleteValueStreamMock = jest.fn(() => Promise.resolve());
  const mockEvent = { preventDefault: jest.fn() };
  const mockToastShow = jest.fn();
  const streamName = 'Cool stream';
  const selectedValueStream = valueStreams[0];
  const deleteValueStreamError = 'Cannot delete default value stream';
  const editValueStreamPathWithId = editValueStreamPath.replace(':id', selectedValueStream.id);

  const fakeStore = ({ initialState = {} }) =>
    new Vuex.Store({
      state: {
        isDeletingValueStream: false,
        deleteValueStreamError: null,
        valueStreams: [],
        selectedValueStream: {},
        ...initialState,
      },
      actions: {
        deleteValueStream: deleteValueStreamMock,
        setSelectedValueStream: jest.fn(),
      },
    });

  const createComponent = ({
    props = {},
    data = {},
    initialState = {},
    provide = {},
    mountFn = shallowMountExtended,
  } = {}) =>
    mountFn(ValueStreamSelect, {
      store: fakeStore({ initialState }),
      data() {
        return {
          ...data,
        };
      },
      propsData: {
        canEdit: true,
        ...props,
      },
      provide: {
        newValueStreamPath,
        editValueStreamPath,
        ...provide,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
      directives: {
        GlModalDirective: createMockDirective('gl-modal-directive'),
      },
    });

  const findDeleteModal = () => wrapper.findComponentByTestId('delete-value-stream-modal');
  const findSelectValueStreamDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateValueStreamOption = () => wrapper.findByTestId('create-value-stream-option');
  const findCreateValueStreamButton = () => wrapper.findByTestId('create-value-stream-button');
  const findEditValueStreamButton = () => wrapper.findByTestId('edit-value-stream');
  const findDeleteValueStreamButton = () => wrapper.findByTestId('delete-value-stream');

  afterEach(() => {
    unmockTracking();
  });

  describe('with value streams available', () => {
    describe('default behaviour', () => {
      beforeEach(() => {
        wrapper = createComponent({
          mountFn: mountExtended,
          initialState: {
            valueStreams,
          },
        });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('does not display the create value stream button', () => {
        expect(findCreateValueStreamButton().exists()).toBe(false);
      });

      it('displays the select value stream dropdown', () => {
        expect(findSelectValueStreamDropdown().exists()).toBe(true);
      });

      it('renders each value stream including a create button', () => {
        const opts = findSelectValueStreamDropdown().props('items');
        valueStreams.forEach((vs, index) => {
          expect(opts[index].text).toBe(vs.name);
        });
      });

      it('tracks dropdown events', () => {
        findSelectValueStreamDropdown().vm.$emit('select', valueStreams[0].id);

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_dropdown', {
          label: 'value_stream_1',
        });
      });
    });

    describe('with a selected value stream', () => {
      describe('with canEdit=true', () => {
        beforeEach(() => {
          wrapper = createComponent({
            mountFn: mountExtended,
            initialState: {
              valueStreams,
              selectedValueStream: {
                ...selectedValueStream,
                isCustom: true,
              },
            },
          });
        });

        it('renders a delete option for custom value streams', () => {
          expect(findDeleteValueStreamButton().exists()).toBe(true);
        });

        it('renders a create option for custom value streams', () => {
          expect(findCreateValueStreamOption().exists()).toBe(true);
          expect(findCreateValueStreamOption().text()).toBe('New value stream');
          expect(findCreateValueStreamOption().attributes('href')).toBe(newValueStreamPath);
        });

        it('renders an edit button for custom value streams', () => {
          expect(findEditValueStreamButton().exists()).toBe(true);
          expect(findEditValueStreamButton().text()).toBe('Edit');
          expect(findEditValueStreamButton().attributes('href')).toBe(editValueStreamPathWithId);
        });
      });

      describe('with canEdit=false', () => {
        beforeEach(() => {
          wrapper = createComponent({
            mountFn: mountExtended,
            initialState: {
              valueStreams,
              selectedValueStream: {
                ...selectedValueStream,
                isCustom: true,
              },
            },
            props: {
              canEdit: false,
            },
          });
        });
        it('does not render a create option for custom value streams', () => {
          expect(findCreateValueStreamOption().exists()).toBe(false);
        });

        it('does not render a delete option for custom value streams', () => {
          expect(findDeleteValueStreamButton().exists()).toBe(false);
        });

        it('does not render an edit button for custom value streams', () => {
          expect(findEditValueStreamButton().exists()).toBe(false);
        });
      });
    });

    describe('with a default value stream', () => {
      beforeEach(() => {
        wrapper = createComponent({ initialState: { valueStreams, selectedValueStream } });
      });

      it('does not render a delete option for default value streams', () => {
        expect(findDeleteValueStreamButton().exists()).toBe(false);
      });

      it('does not render an edit button for default value streams', () => {
        expect(findEditValueStreamButton().exists()).toBe(false);
      });
    });
  });

  describe('Only the default value stream available', () => {
    beforeEach(() => {
      wrapper = createComponent({
        initialState: {
          valueStreams: [{ id: 'default', name: 'default' }],
        },
      });
    });

    it('does not display the create value stream button', () => {
      expect(findCreateValueStreamButton().exists()).toBe(false);
    });

    it('displays the select value stream dropdown', () => {
      expect(findSelectValueStreamDropdown().exists()).toBe(true);
    });

    it('does not render an edit button for default value streams', () => {
      expect(findEditValueStreamButton().exists()).toBe(false);
    });
  });

  describe('No value streams available', () => {
    beforeEach(() => {
      wrapper = createComponent({
        initialState: {
          valueStreams: [],
        },
      });
    });

    it('displays the create value stream button', () => {
      expect(findCreateValueStreamButton().exists()).toBe(true);
      expect(findCreateValueStreamButton().attributes('href')).toBe(newValueStreamPath);
    });

    it('does not display the select value stream dropdown', () => {
      expect(findSelectValueStreamDropdown().exists()).toBe(false);
    });

    it('does not render an edit button for default value streams', () => {
      expect(findEditValueStreamButton().exists()).toBe(false);
    });
  });

  describe('Delete value stream modal', () => {
    describe('succeeds', () => {
      beforeEach(() => {
        wrapper = createComponent({
          initialState: {
            valueStreams,
            selectedValueStream: {
              ...selectedValueStream,
              isCustom: true,
            },
          },
        });

        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

        findDeleteModal().vm.$emit('primary', mockEvent);
      });

      it('calls the "deleteValueStream" event when submitted', () => {
        expect(deleteValueStreamMock).toHaveBeenCalledWith(
          expect.any(Object),
          selectedValueStream.id,
        );
      });

      it('displays a toast message', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          `'${selectedValueStream.name}' Value Stream deleted`,
        );
      });

      it('sends tracking information', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'delete_value_stream', {
          extra: { name: selectedValueStream.name },
        });
      });

      it('dismisses value stream created/updated success alert', () => {
        expect(dismissGlobalAlertById).toHaveBeenCalledTimes(1);
        expect(dismissGlobalAlertById).toHaveBeenCalledWith('vsa-settings-form-submission-success');
      });
    });

    describe('fails', () => {
      beforeEach(() => {
        wrapper = createComponent({
          data: { name: streamName },
          initialState: { deleteValueStreamError },
        });
      });

      it('does not display a toast message', () => {
        expect(mockToastShow).not.toHaveBeenCalled();
      });
    });
  });
});
