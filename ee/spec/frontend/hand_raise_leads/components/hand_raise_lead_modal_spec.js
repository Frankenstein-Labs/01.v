import { GlModal, GlFormFields } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createWrapper } from '@vue/test-utils';
import { sprintf } from '~/locale';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockTracking } from 'helpers/tracking_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import HandRaiseLeadModal from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_modal.vue';
import ListboxInput from '~/vue_shared/components/listbox_input/listbox_input.vue';
import {
  PQL_MODAL_PRIMARY,
  PQL_MODAL_CANCEL,
  PQL_MODAL_HEADER_TEXT,
  PQL_MODAL_FOOTER_TEXT,
  PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
} from 'ee/hand_raise_leads/hand_raise_lead/constants';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import eventHub from 'ee/hand_raise_leads/hand_raise_lead/event_hub';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import waitForPromises from 'helpers/wait_for_promises';
import {
  USER,
  CREATE_HAND_RAISE_LEAD_PATH,
  GLM_CONTENT,
  PRODUCT_INTERACTION,
  COUNTRIES,
  STATES,
  COUNTRY_WITH_STATES,
  STATE,
} from './mock_data';

Vue.use(VueApollo);

describe('HandRaiseLeadModal', () => {
  let wrapper;
  let trackingSpy;

  const createComponent = async ({
    props = {},
    countriesLoading = false,
    statesLoading = false,
  } = {}) => {
    const mockResolvers = {
      Query: {
        countries() {
          if (countriesLoading) {
            return new Promise(() => {});
          }
          return COUNTRIES;
        },
        states() {
          if (statesLoading) {
            return new Promise(() => {});
          }
          return STATES;
        },
      },
    };

    const component = shallowMountExtended(HandRaiseLeadModal, {
      apolloProvider: createMockApollo([], mockResolvers),
      propsData: {
        submitPath: CREATE_HAND_RAISE_LEAD_PATH,
        user: USER,
        ...props,
      },
      stubs: {
        ListboxInput,
      },
    });

    if (!countriesLoading && !statesLoading) {
      await waitForPromises();
    }

    return component;
  };

  const expectTracking = (action) =>
    expect(trackingSpy).toHaveBeenCalledWith(undefined, action, {
      label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
    });

  const findModal = () => wrapper.findComponent(GlModal);
  const findFormFields = () => wrapper.findComponent(GlFormFields);
  const findCountrySelect = () => wrapper.findComponentByTestId('country-dropdown');
  const findStateSelect = () => wrapper.findComponentByTestId('state-dropdown');
  const fieldsProps = () => findFormFields().props('fields');
  const triggerOpenModal = async ({
    productInteraction = PRODUCT_INTERACTION,
    ctaTracking = {},
    glmContent = GLM_CONTENT,
  } = {}) => {
    eventHub.$emit('openModal', { productInteraction, ctaTracking, glmContent });
    await nextTick();
  };
  const submitForm = () => findModal().vm.$emit('primary');

  describe('rendering', () => {
    let rootWrapper;

    beforeEach(async () => {
      wrapper = await createComponent();
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      rootWrapper = createWrapper(wrapper.vm.$root);
    });

    it('passes the correct fields to GlFormFields', () => {
      expect(findFormFields().exists()).toBe(true);

      const expectedFields = [
        { key: 'firstName', name: 'first_name' },
        { key: 'lastName', name: 'last_name' },
        { key: 'companyName', name: 'company_name' },
        { key: 'phoneNumber', name: 'phone_number' },
        { key: 'country', name: undefined },
        { key: 'comment', name: undefined },
      ];

      expectedFields.forEach(({ key, name }) => {
        expect(fieldsProps()).toHaveProperty(key);
        if (name !== undefined) {
          expect(fieldsProps()[key].inputAttrs).toHaveProperty('name', name);
        }
      });
    });

    it('correctly binds formValues to GlFormFields via v-model', async () => {
      expect(findFormFields().props('values')).toEqual(wrapper.vm.formValues);

      const updatedValues = {
        ...wrapper.vm.formValues,
        company_name: 'New Company Name',
      };

      findFormFields().vm.$emit('input', updatedValues);
      await nextTick();

      expect(findFormFields().props('values')).toEqual(updatedValues);
    });

    it('has the correct text in the modal content', () => {
      expect(findModal().text()).toContain(sprintf(PQL_MODAL_HEADER_TEXT, { userName: 'joe' }));
      expect(findModal().text()).toContain(PQL_MODAL_FOOTER_TEXT);
    });

    it('has the correct modal props', () => {
      expect(findModal().props('actionPrimary')).toStrictEqual({
        text: PQL_MODAL_PRIMARY,
        attributes: { variant: 'confirm', disabled: true, class: 'gl-w-full @sm:gl-w-auto' },
      });
      expect(findModal().props('actionCancel')).toStrictEqual({
        text: PQL_MODAL_CANCEL,
        attributes: { class: 'gl-w-full @sm:gl-w-auto' },
      });
    });

    it('tracks modal view', async () => {
      await triggerOpenModal();

      expectTracking('hand_raise_form_viewed');
    });

    it('opens the modal', async () => {
      await triggerOpenModal();

      expect(rootWrapper.emitted(BV_SHOW_MODAL)).toHaveLength(1);
    });

    describe('country field', () => {
      it('does not show country field when Apollo is loading countries', async () => {
        wrapper = await createComponent({ countriesLoading: true });
        await triggerOpenModal();
        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('country');
      });

      it('shows country field when Apollo is not loading countries', async () => {
        wrapper = await createComponent();
        await triggerOpenModal();
        await waitForPromises();
        await nextTick();

        expect(fieldsProps()).toHaveProperty('country');
      });
    });

    describe('state field', () => {
      it('does not show state field when Apollo is loading states', async () => {
        wrapper = await createComponent({ statesLoading: true });
        await triggerOpenModal();

        await nextTick();

        expect(fieldsProps()).not.toHaveProperty('state');
      });

      it('shows state field when country requires state', async () => {
        wrapper = await createComponent();
        await triggerOpenModal();

        const updatedValues = {
          ...wrapper.vm.formValues,
          country: COUNTRY_WITH_STATES,
        };
        findFormFields().vm.$emit('input', updatedValues);
        await nextTick();
        await waitForPromises();

        expect(fieldsProps()).toHaveProperty('state');
      });

      it('does not show state field when country does not require state', async () => {
        wrapper = await createComponent();
        await triggerOpenModal();

        const updatedValues = {
          ...wrapper.vm.formValues,
          country: 'NL',
        };
        findFormFields().vm.$emit('input', updatedValues);
        await nextTick();
        await waitForPromises();

        expect(fieldsProps()).not.toHaveProperty('state');
      });
    });
  });

  describe('submit button', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it('becomes enabled when required info is there', async () => {
      const updatedValues = {
        ...wrapper.vm.formValues,
        firstName: 'Joe',
        lastName: 'Doe',
        companyName: 'ACME',
        phoneNumber: '192919',
        country: COUNTRY_WITH_STATES,
        state: STATE,
      };

      findFormFields().vm.$emit('input', updatedValues);
      await nextTick();

      expect(findModal().props('actionPrimary')).toStrictEqual({
        text: PQL_MODAL_PRIMARY,
        attributes: { variant: 'confirm', disabled: false, class: 'gl-w-full @sm:gl-w-auto' },
      });
    });
  });

  describe('form submission', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

      const updatedValues = {
        ...wrapper.vm.formValues,
        firstName: 'Joe',
        lastName: 'Doe',
        companyName: 'ACME',
        phoneNumber: '192919',
        country: COUNTRY_WITH_STATES,
        state: STATE,
        comment: 'test comment',
      };

      findFormFields().vm.$emit('input', updatedValues);
      await nextTick();
    });

    describe('successful submission', () => {
      beforeEach(async () => {
        jest.spyOn(SubscriptionsApi, 'sendHandRaiseLead').mockResolvedValue();

        await triggerOpenModal();

        submitForm();
      });

      it('submits the valid form with correct data', () => {
        expect(SubscriptionsApi.sendHandRaiseLead).toHaveBeenCalledWith(
          CREATE_HAND_RAISE_LEAD_PATH,
          {
            namespaceId: 1,
            firstName: 'Joe',
            lastName: 'Doe',
            companyName: 'ACME',
            phoneNumber: '192919',
            country: COUNTRY_WITH_STATES,
            state: STATE,
            comment: 'test comment',
            glmContent: GLM_CONTENT,
            productInteraction: PRODUCT_INTERACTION,
          },
        );
      });

      it('tracks successful submission', () => {
        expectTracking('hand_raise_submit_form_succeeded');
      });
    });

    describe('failed submission', () => {
      beforeEach(async () => {
        jest.spyOn(SubscriptionsApi, 'sendHandRaiseLead').mockRejectedValue();

        await triggerOpenModal();

        submitForm();
      });

      it('tracks failed submission', () => {
        expectTracking('hand_raise_submit_form_failed');
      });
    });

    describe('form cancel', () => {
      beforeEach(() => {
        findModal().vm.$emit('cancel');
      });

      it('tracks cancel', () => {
        expectTracking('hand_raise_form_canceled');
      });
    });
  });

  describe('GraphQL query behavior', () => {
    it('loads countries only after modal is opened', async () => {
      const mockResolvers = {
        Query: {
          countries: jest.fn().mockReturnValue(COUNTRIES),
          states: jest.fn().mockReturnValue(STATES),
        },
      };

      wrapper = shallowMountExtended(HandRaiseLeadModal, {
        apolloProvider: createMockApollo([], mockResolvers),
        propsData: {
          submitPath: CREATE_HAND_RAISE_LEAD_PATH,
          user: USER,
        },
        stubs: {
          ListboxInput,
        },
      });

      await nextTick();

      expect(mockResolvers.Query.countries).not.toHaveBeenCalled();
      expect(mockResolvers.Query.states).not.toHaveBeenCalled();

      await triggerOpenModal();
      await waitForPromises();

      expect(mockResolvers.Query.countries).toHaveBeenCalled();
    });
  });

  describe('country and state field behavior', () => {
    beforeEach(async () => {
      wrapper = await createComponent();
    });

    it('renders country field after countries are loaded', async () => {
      // Enable queries and wait for them to load
      await triggerOpenModal();
      await waitForPromises();
      await nextTick();

      expect(findCountrySelect().props('items').length).toBeGreaterThan(1);
    });

    it('renders state field after selecting a country that requires states', async () => {
      await triggerOpenModal();
      await waitForPromises();
      await nextTick();

      const updatedValues = {
        ...wrapper.vm.formValues,
        country: COUNTRY_WITH_STATES,
      };
      findFormFields().vm.$emit('input', updatedValues);
      await nextTick();
      await waitForPromises();

      expect(fieldsProps()).toHaveProperty('state');
      expect(findStateSelect().props('items').length).toBeGreaterThan(1);
    });

    it('has the proper state show and hide logic based on the selected country', async () => {
      await triggerOpenModal();
      await waitForPromises();
      await nextTick();

      const updatedValuesNL = {
        ...wrapper.vm.formValues,
        country: 'NL',
      };

      findFormFields().vm.$emit('input', updatedValuesNL);
      await nextTick();
      await waitForPromises();

      expect(fieldsProps()).not.toHaveProperty('state');

      const updatedValuesUS = {
        ...wrapper.vm.formValues,
        country: COUNTRY_WITH_STATES,
      };
      findFormFields().vm.$emit('input', updatedValuesUS);
      await nextTick();
      await waitForPromises();

      expect(fieldsProps()).toHaveProperty('state');
    });
  });
});
