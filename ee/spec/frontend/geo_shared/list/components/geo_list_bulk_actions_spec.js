import { GlModal, GlSprintf, GlButton, GlLink, GlDisclosureDropdown } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import GeoListBulkActions from 'ee/geo_shared/list/components/geo_list_bulk_actions.vue';
import { MOCK_BULK_ACTIONS, MOCK_ADDITIONAL_BULK_ACTION } from '../mock_data';

const MOCK_BULK_ACTION_WITH_ONE_ADDITIONAL_ACTIONS = [
  {
    ...MOCK_BULK_ACTIONS[0],
    additionalActions: [MOCK_ADDITIONAL_BULK_ACTION],
  },
];

const MOCK_BULK_ACTIONS_WITH_MULTIPLE_ADDITIONAL_ACTIONS = [
  {
    ...MOCK_BULK_ACTIONS[0],
    additionalActions: [
      MOCK_ADDITIONAL_BULK_ACTION,
      MOCK_ADDITIONAL_BULK_ACTION,
      MOCK_ADDITIONAL_BULK_ACTION,
    ],
  },
  MOCK_BULK_ACTIONS[1],
];

describe('GeoListBulkActions', () => {
  let wrapper;

  const defaultProvide = {
    itemTitle: 'Test Item',
  };

  const defaultProps = {
    bulkActions: MOCK_BULK_ACTIONS,
  };

  const GlModalStub = stubComponent(GlModal, { methods: { show: jest.fn() } });

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(GeoListBulkActions, {
      provide: { ...defaultProvide },
      propsData: { ...defaultProps, ...props },
      stubs: { GlSprintf, GlModal: GlModalStub },
    });
  };

  const findBulkActions = () => wrapper.findAllComponents(GlButton);
  const findGlModal = () => wrapper.findComponent(GlModal);
  const findGlDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

  describe('Actions', () => {
    describe('when there are not additional nested bulk actions', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders a button for each bulk action', () => {
        expect(findBulkActions()).toHaveLength(defaultProps.bulkActions.length);
      });

      it('does not render a disclosure dropdown', () => {
        expect(findGlDisclosureDropdown().exists()).toBe(false);
      });
    });

    describe('when there is one additional nested bulk actions', () => {
      beforeEach(() => {
        createComponent({ props: { bulkActions: MOCK_BULK_ACTION_WITH_ONE_ADDITIONAL_ACTIONS } });
      });

      it('renders a button for each bulk action', () => {
        expect(findBulkActions()).toHaveLength(MOCK_BULK_ACTION_WITH_ONE_ADDITIONAL_ACTIONS.length);
      });

      it('does render a disclosure dropdown and properly formats its props', () => {
        const expectedProps = [
          { text: MOCK_ADDITIONAL_BULK_ACTION.text, extraAttrs: MOCK_ADDITIONAL_BULK_ACTION },
        ];
        expect(findGlDisclosureDropdown().props('items')).toStrictEqual(expectedProps);
      });
    });

    describe('when there are multiple additional nested bulk actions', () => {
      beforeEach(() => {
        createComponent({
          props: { bulkActions: MOCK_BULK_ACTIONS_WITH_MULTIPLE_ADDITIONAL_ACTIONS },
        });
      });

      it('renders a button for each bulk action', () => {
        expect(findBulkActions()).toHaveLength(
          MOCK_BULK_ACTIONS_WITH_MULTIPLE_ADDITIONAL_ACTIONS.length,
        );
      });

      it('does render a disclosure dropdown and properly formats its props', () => {
        const expectedProps =
          MOCK_BULK_ACTIONS_WITH_MULTIPLE_ADDITIONAL_ACTIONS[0].additionalActions.map((action) => {
            return {
              text: action.text,
              extraAttrs: action,
            };
          });

        expect(findGlDisclosureDropdown().props('items')).toStrictEqual(expectedProps);
      });
    });
  });

  describe('Modal', () => {
    describe('with primary bulk actions', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not have content before action is clicked', () => {
        expect(findGlModal().props('title')).toBeNull();
        expect(findGlModal().text()).toBe('');
      });

      it('properly renders when bulk action is clicked', async () => {
        findBulkActions().at(0).vm.$emit('click');
        await nextTick();

        expect(findGlModal().props('title')).toBe(`Test action on ${defaultProvide.itemTitle}`);
        expect(findGlModal().text()).toContain(`Executes action on ${defaultProvide.itemTitle}`);
      });

      it('properly emits `bulk-action` when modal primary action is executed', async () => {
        findBulkActions().at(0).vm.$emit('click');
        await nextTick();

        findGlModal().vm.$emit('primary');
        await nextTick();

        expect(wrapper.emitted('bulk-action')).toStrictEqual([[defaultProps.bulkActions[0]]]);
      });
    });

    describe('with additional bulk actions', () => {
      beforeEach(() => {
        createComponent({ props: { bulkActions: MOCK_BULK_ACTION_WITH_ONE_ADDITIONAL_ACTIONS } });
      });

      it('does not have content before action is clicked', () => {
        expect(findGlModal().props('title')).toBeNull();
        expect(findGlModal().text()).toBe('');
      });

      it('properly renders when the additional bulk action is clicked', async () => {
        findGlDisclosureDropdown().vm.$emit('action', {
          text: MOCK_ADDITIONAL_BULK_ACTION.text,
          extraAttrs: MOCK_ADDITIONAL_BULK_ACTION,
        });
        await nextTick();

        expect(findGlModal().props('title')).toBe(`Test action on ${defaultProvide.itemTitle}`);
        expect(findGlModal().text()).toContain(`Executes action on ${defaultProvide.itemTitle}`);
      });

      it('properly emits `bulk-action` when modal primary action is executed', async () => {
        findGlDisclosureDropdown().vm.$emit('action', {
          text: MOCK_ADDITIONAL_BULK_ACTION.text,
          extraAttrs: MOCK_ADDITIONAL_BULK_ACTION,
        });
        await nextTick();

        findGlModal().vm.$emit('primary');
        await nextTick();

        expect(wrapper.emitted('bulk-action')).toStrictEqual([[MOCK_ADDITIONAL_BULK_ACTION]]);
      });
    });
  });

  describe('Modal help links', () => {
    describe('when link is not provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render the modal help link', async () => {
        findBulkActions().at(0).vm.$emit('click');
        await nextTick();

        expect(findGlModal().findComponent(GlLink).exists()).toBe(false);
      });
    });

    describe('when link is provided', () => {
      beforeEach(() => {
        createComponent({
          props: {
            bulkActions: [
              {
                ...MOCK_BULK_ACTIONS[0],
                modal: {
                  title: 'Test title',
                  description: 'Test description',
                  helpLink: {
                    text: 'Help link',
                    href: '/help/link',
                  },
                },
              },
            ],
          },
        });
      });

      it('does render the modal help link', async () => {
        findBulkActions().at(0).vm.$emit('click');
        await nextTick();

        expect(findGlModal().findComponent(GlLink).text()).toBe('Help link');
        expect(findGlModal().findComponent(GlLink).props('href')).toBe('/help/link');
      });
    });
  });
});
